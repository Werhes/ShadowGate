use crate::config::*;
use crate::ws::{ws_connect_once, RawWebSocket, WsError};
use serde::Deserialize;
use std::time::{Duration, Instant};
use tokio::sync::Semaphore;

use once_cell::sync::Lazy;
static CFPROXY_SEM: Lazy<Semaphore> = Lazy::new(|| Semaphore::new(CFPROXY_GLOBAL_PARALLEL));

// ---------------------------------------------------------------------------
// Domain decoding
// ---------------------------------------------------------------------------

pub fn decode_cf_domain(s: &str) -> String {
    if !s.ends_with(".com") {
        return s.to_string();
    }
    let suffix = ".co.uk";
    let p = &s[..s.len() - 4];
    let mut n = 0i32;
    for c in p.chars() {
        if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
            n += 1;
        }
    }
    let mut result: Vec<u8> = Vec::new();
    for &c in p.as_bytes() {
        if c >= b'a' && c <= b'z' {
            let v = (((c - b'a') as i32 - n % 26 + 26) % 26) as u8 + b'a';
            result.push(v);
        } else if c >= b'A' && c <= b'Z' {
            let v = (((c - b'A') as i32 - n % 26 + 26) % 26) as u8 + b'A';
            result.push(v);
        } else {
            result.push(c);
        }
    }
    let mut out = String::from_utf8_lossy(&result).to_string();
    out.push_str(suffix);
    out
}

pub fn normalize_cf_domain(s: &str) -> String {
    let mut decoded = decode_cf_domain(s.trim()).trim().to_lowercase();
    while decoded.ends_with('.') {
        decoded.pop();
    }
    if decoded.is_empty() || !decoded.ends_with(".co.uk") {
        return String::new();
    }
    decoded
}

pub fn default_cfproxy_domains() -> Vec<String> {
    let mut domains = Vec::with_capacity(CFPROXY_ENC.len());
    for enc in CFPROXY_ENC {
        let d = normalize_cf_domain(enc);
        if !d.is_empty() {
            domains.push(d);
        }
    }
    domains
}

pub fn merge_cfproxy_domains(lists: &[Vec<String>]) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut merged = Vec::new();
    for list in lists {
        for raw in list {
            let d = normalize_cf_domain(raw);
            if d.is_empty() || seen.contains(&d) {
                continue;
            }
            seen.insert(d.clone());
            merged.push(d);
        }
    }
    merged
}

// ---------------------------------------------------------------------------
// 429 cooldown logic
// ---------------------------------------------------------------------------

pub fn clear_cfproxy_429_cooldowns() {
    CFPROXY_429.write().clear();
}

pub fn clear_cfproxy_429_cooldown(domain: &str) {
    let d = normalize_cf_domain(domain);
    if d.is_empty() {
        return;
    }
    CFPROXY_429.write().remove(&d);
}

pub fn retry_after_delay(err: &WsError) -> Duration {
    let h = match err.handshake() {
        Some(h) => h,
        None => return Duration::ZERO,
    };
    let retry_after = h.headers.get("retry-after").map(|s| s.trim()).unwrap_or("");
    if retry_after.is_empty() {
        return Duration::ZERO;
    }
    if let Ok(seconds) = retry_after.parse::<i64>() {
        if seconds > 0 {
            return Duration::from_secs(seconds as u64);
        }
    }
    Duration::ZERO
}

pub fn next_cfproxy_429_cooldown_delay(prev: &Cfproxy429State, retry_after: Duration) -> Duration {
    if retry_after > Duration::ZERO {
        if retry_after > CFPROXY_429_MAX_COOLDOWN {
            return CFPROXY_429_MAX_COOLDOWN;
        }
        return retry_after;
    }
    let mut strikes = prev.strikes;
    let expired = match prev.until {
        None => true,
        Some(u) => u.elapsed() > CFPROXY_429_MAX_COOLDOWN,
    };
    if expired {
        strikes = 0;
    }
    let mut delay = CFPROXY_429_COOLDOWN;
    for _ in 0..strikes {
        delay *= 2;
        if delay >= CFPROXY_429_MAX_COOLDOWN {
            return CFPROXY_429_MAX_COOLDOWN;
        }
    }
    if delay > CFPROXY_429_MAX_COOLDOWN {
        return CFPROXY_429_MAX_COOLDOWN;
    }
    delay
}

pub fn mark_cfproxy_429_cooldown(domain: &str, err: &WsError) {
    let d = normalize_cf_domain(domain);
    if d.is_empty() {
        return;
    }
    let retry_after = retry_after_delay(err);
    let mut map = CFPROXY_429.write();
    let prev = map.get(&d).cloned().unwrap_or_default();
    let delay = next_cfproxy_429_cooldown_delay(&prev, retry_after);
    let mut strikes = prev.strikes + 1;
    let expired = match prev.until {
        None => true,
        Some(u) => u.elapsed() > CFPROXY_429_MAX_COOLDOWN,
    };
    if expired {
        strikes = 1;
    }
    map.insert(
        d.clone(),
        Cfproxy429State {
            until: Some(Instant::now() + delay),
            strikes,
        },
    );
    drop(map);
    ldebug!(" CF cooldown {}: {:.0}s after 429", d, delay.as_secs_f64().ceil());
}

pub fn cfproxy_429_cooldown_remaining(domain: &str) -> Duration {
    let d = normalize_cf_domain(domain);
    if d.is_empty() {
        return Duration::ZERO;
    }
    let map = CFPROXY_429.read();
    let state = match map.get(&d) {
        Some(s) => s.clone(),
        None => return Duration::ZERO,
    };
    drop(map);
    let until = match state.until {
        Some(u) => u,
        None => return Duration::ZERO,
    };
    let now = Instant::now();
    if until <= now {
        CFPROXY_429.write().remove(&d);
        return Duration::ZERO;
    }
    until - now
}

pub async fn acquire_cfproxy_attempt_slot() -> Option<tokio::sync::SemaphorePermit<'static>> {
    CFPROXY_SEM.acquire().await.ok()
}

// ---------------------------------------------------------------------------
// DoH resolver
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct DnsAnswer {
    #[serde(rename = "type")]
    pub qtype: u16,
    pub data: String,
}

#[derive(Deserialize)]
struct DnsQuestion {
    pub name: String,
}

#[derive(Deserialize)]
struct DnsResponse {
    pub answer: Option<Vec<DnsAnswer>>,
}

/// DNS-over-HTTPS резолвинг через Cloudflare
pub async fn resolve_doh(domain: &str) -> Option<String> {
    let url = format!("https://cloudflare-dns.com/dns-query?name={}&type=A", domain);
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .use_rustls_tls()
        .build()
        .ok()?;

    let resp = client
        .get(&url)
        .header("accept", "application/dns-json")
        .send()
        .await
        .ok()?;

    let dns: DnsResponse = resp.json().await.ok()?;
    let answer = dns.answer?;
    for a in answer {
        if a.qtype == 1 {
            // A record
            return Some(a.data);
        }
    }
    None
}

// ---------------------------------------------------------------------------
// CF connect
// ---------------------------------------------------------------------------

pub async fn cf_connect_domain(
    domain: &str,
    path: &str,
    timeout: f64,
) -> (Option<RawWebSocket>, String, Option<WsError>) {
    let attempt_timeout = Duration::from_secs_f64(timeout);

    // Пробуем прямое подключение по домену (резолвится системой)
    match ws_connect_once(domain, domain, path, attempt_timeout).await {
        Ok(ws) => return (Some(ws), domain.to_string(), None),
        Err(e) => {
            // Пробуем DoH резолвинг
            if let Some(ip) = resolve_doh(domain).await {
                match ws_connect_once(&ip, domain, path, attempt_timeout).await {
                    Ok(ws) => return (Some(ws), ip, None),
                    Err(e2) => return (None, ip, Some(e2)),
                }
            }
            return (None, String::new(), Some(e));
        }
    }
}

// ---------------------------------------------------------------------------
// CF proxy refresh
// ---------------------------------------------------------------------------

pub fn init_cfproxy_domains() {
    let defaults = default_cfproxy_domains();
    let mut cfg = CFPROXY.write();
    if cfg.domains.is_empty() {
        cfg.domains = defaults;
        if !cfg.domains.is_empty() {
            cfg.active = cfg.domains[0].clone();
        }
    }
    drop(cfg);

    let mut balancer = crate::balancer::BALANCER.write();
    let cfg = CFPROXY.read();
    balancer.update_domains_list(&cfg.domains);
}

pub fn start_cfproxy_refresh() {
    tokio::spawn(async {
        let mut interval = tokio::time::interval(CFPROXY_REFRESH_INTERVAL);
        interval.tick().await;
        loop {
            interval.tick().await;
            refresh_cfproxy_domains().await;
        }
    });
}

async fn refresh_cfproxy_domains() {
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(10))
        .use_rustls_tls()
        .build()
        .ok();

    let client = match client {
        Some(c) => c,
        None => return,
    };

    let resp = client.get(CFPROXY_DOMAINS_URL).send().await;
    let text = match resp {
        Ok(r) => r.text().await.unwrap_or_default(),
        Err(_) => return,
    };

    let mut remote_domains: Vec<String> = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let d = normalize_cf_domain(line);
        if !d.is_empty() {
            remote_domains.push(d);
        }
    }

    if remote_domains.is_empty() {
        return;
    }

    let mut cfg = CFPROXY.write();
    let merged = merge_cfproxy_domains(&[cfg.domains.clone(), remote_domains]);
    cfg.domains = merged;
    if cfg.active.is_empty() && !cfg.domains.is_empty() {
        cfg.active = cfg.domains[0].clone();
    }
    drop(cfg);

    let mut balancer = crate::balancer::BALANCER.write();
    let cfg = CFPROXY.read();
    balancer.update_domains_list(&cfg.domains);
}