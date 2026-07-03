use crate::config::*;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::windows::named_pipe::{ClientOptions, ServerOptions};
use tokio_util::sync::CancellationToken;

const PIPE_NAME: &str = r"\\.\pipe\ShadowGateMtprotoProxy";

/// Запуск Windows Named Pipe сервера для коммуникации с Dart FFI
pub async fn run_pipe_server(cancel_token: CancellationToken) {
    loop {
        let server = ServerOptions::new()
            .first_pipe_instance(true)
            .create(PIPE_NAME);

        let mut server = match server {
            Ok(s) => s,
            Err(_) => {
                // Если уже есть экземпляр — ждём
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                continue;
            }
        };

        tokio::select! {
            _ = cancel_token.cancelled() => break,
            result = server.connect() => {
                if let Err(e) = result {
                    lerror!("Pipe connect error: {}", e);
                    continue;
                }

                // NamedPipeServer реализует AsyncRead + AsyncWrite,
                // но не AsyncBufRead, поэтому split() не работает.
                // Читаем напрямую через read().
                let mut buf = vec![0u8; 4096];
                match server.read(&mut buf).await {
                    Ok(0) | Err(_) => continue,
                    Ok(n) => {
                        let cmd = String::from_utf8_lossy(&buf[..n]).trim().to_string();
                        let response = handle_pipe_command(&cmd);
                        if let Err(e) = server.write_all(response.as_bytes()).await {
                            lerror!("Pipe write error: {}", e);
                        }
                    }
                }
            }
        }
    }
}

fn handle_pipe_command(cmd: &str) -> String {
    let parts: Vec<&str> = cmd.splitn(2, ' ').collect();
    let command = parts[0];

    match command {
        "stats" => {
            STATS.summary()
        }
        "secret" => {
            format!("dd{}", PROXY_SECRET.read().clone())
        }
        "ping" => {
            "pong".to_string()
        }
        _ => {
            format!("unknown command: {}", command)
        }
    }
}

/// Отправка команды в Named Pipe (для Dart FFI)
pub fn send_pipe_command(command: &str) -> Result<String, String> {
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| e.to_string())?;

    rt.block_on(async {
        let mut client = ClientOptions::new()
            .open(PIPE_NAME)
            .map_err(|e| format!("Failed to open pipe: {}", e))?;

        // Отправляем команду
        let cmd = format!("{}\n", command);
        client
            .write_all(cmd.as_bytes())
            .await
            .map_err(|e| format!("Failed to write to pipe: {}", e))?;

        // Читаем ответ — NamedPipeClient реализует AsyncRead
        let mut buf = vec![0u8; 4096];
        let n = client
            .read(&mut buf)
            .await
            .map_err(|e| format!("Failed to read from pipe: {}", e))?;

        let response = String::from_utf8_lossy(&buf[..n]).trim().to_string();
        Ok(response)
    })
}