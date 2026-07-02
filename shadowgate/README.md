# ShadowGate 🔒

**Разработчик:** [werhes](https://github.com/werhes)

**ShadowGate** — кроссплатформенное Flutter-приложение для обхода блокировок. Работает в двух режимах: **прокси** (HTTP/SOCKS5) и **TUN** (с DPI-обходом).

## Возможности

### 🚀 Два режима работы

| Режим | Описание |
|-------|----------|
| **Прокси** | Локальный HTTP/SOCKS5 прокси-сервер. Поддерживает HTTPS CONNECT туннелирование и SOCKS5 (RFC 1928) с аутентификацией |
| **TUN** | Виртуальный сетевой интерфейс с полным DPI-обходом (фрагментация TCP, изменение TTL, подмена Host, перепаковка пакетов, TLS-обфускация) |

### 🎯 Целевые сервисы

Предустановленные цели для обхода блокировок:

- **Telegram** — api.telegram.org, t.me, telegram.org
- **Discord** — discord.com, discord.gg, discordapp.net
- **YouTube** — youtube.com, googlevideo.com, ytimg.com

Возможно добавление **пользовательских целей** с указанием доменов, IP-диапазонов (CIDR) и портов.

### 🛡️ Методы DPI-обхода (TUN-режим)

| Метод | Описание |
|-------|----------|
| Фрагментация TCP | Разбиение TCP-пакетов на мелкие фрагменты (MSS clamping) |
| Изменение TTL | Установка TTL=1 для первого пакета handshake |
| Подмена Host | Маскировка Host header под легитимный трафик |
| Перепаковка пакетов | Изменение порядка TCP-сегментов |
| TLS-обфускация | Добавление случайных данных в TLS ClientHello |

### 📊 Интерфейс

- Тёмная тема (Material 3)
- Выбор режима работы (Proxy/TUN)
- Мониторинг трафика в реальном времени (скорость, объём)
- Просмотр логов с автоскроллом
- Управление целевыми сервисами
- Настройки прокси (тип, адрес, порт, WebSocket)
- Настройки TUN (интерфейс, MTU, DNS, методы DPI)

## Установка

### Требования

- Flutter SDK 3.12+
- Dart SDK 3.12+
- Для Windows: Visual Studio 2022 с C++ компонентами
- Для Android: Android Studio, SDK 21+
- Для macOS/iOS: Xcode 15+

### Сборка

```bash
# Клонирование
git clone https://github.com/Werhes/ShadowGate.git
cd shadowgate

# Установка зависимостей
flutter pub get

# Запуск
flutter run

# Сборка для Windows
flutter build windows

# Сборка для Android
flutter build apk

# Сборка для macOS
flutter build macos

# Сборка для iOS
flutter build ios
```

## Использование

1. **Запустите приложение**
2. **Выберите режим**: Прокси или TUN
3. **Настройте конфигурацию** (опционально):
   - Для прокси: тип (HTTP/SOCKS5), порт, WebSocket
   - Для TUN: методы DPI, MTU, DNS
4. **Выберите цели**: Telegram, Discord, YouTube или добавьте свои
5. **Нажмите "Запустить"**
6. **Настройте приложение/систему** на использование прокси (для прокси-режима)

## Архитектура

```
lib/
├── main.dart                    # Точка входа
├── app.dart                     # MaterialApp с Provider
├── core/                        # Базовые типы и константы
├── models/                      # Модели данных
├── services/                    # Бизнес-логика
│   ├── proxy_service.dart       # HTTP/SOCKS5 прокси-сервер
│   ├── socks5_handler.dart      # SOCKS5 протокол (RFC 1928)
│   ├── tun_service.dart         # TUN-интерфейс
│   ├── dpi_bypass_service.dart  # DPI-обход
│   ├── target_manager.dart      # Управление целями
│   └── platform_channel_service.dart
├── providers/                   # State management (Provider)
├── ui/                          # Пользовательский интерфейс
│   ├── screens/                 # Экраны
│   ├── widgets/                 # Виджеты
│   └── theme/                   # Тема
└── utils/                       # Утилиты
```

## Платформенная интеграция

TUN-режим требует нативной реализации для каждой платформы:

| Платформа | Технология |
|-----------|-----------|
| **Windows** | WinDivert (C++ FFI) |
| **Android** | VpnService (Kotlin) |
| **macOS** | utun (Swift) |
| **iOS** | NEPacketTunnelProvider (Swift) |

## Технологии

- **Flutter** — кроссплатформенный UI
- **Provider** — управление состоянием
- **SharedPreferences** — хранение настроек
- **dart:io** — HTTP/SOCKS5 сервер
- **Material 3** — дизайн

## Лицензия

MIT License. Подробнее в файле [LICENSE](LICENSE).

## CI/CD

Проект использует **GitHub Actions** для автоматической сборки и публикации релизов.

### Workflow: Build & Release

Файл: [`.github/workflows/build-release.yml`](.github/workflows/build-release.yml)

**Запуск:**
- Автоматически при пуше тега `v*` (например, `v1.0.0`)
- Вручную через вкладку Actions → Build & Release → Run workflow

**Параметры ручного запуска:**
| Параметр | Описание |
|----------|----------|
| `version` | Версия релиза (например, `1.0.0`) |
| `prerelease` | Отметить как пре-релиз |
| `release_title` | Название релиза |
| `release_notes` | Описание релиза |

**Сборка для платформ:**
| Платформа | Артефакт | Runner |
|-----------|----------|--------|
| Windows | ZIP-архив | `windows-latest` |
| Android | APK + AAB | `ubuntu-latest` |
| iOS | IPA | `macos-latest` |
| macOS | ZIP-архив | `macos-latest` |

**Telegram-уведомления:**
После завершения сборки отправляется уведомление в Telegram со статусом всех платформ и ссылкой на релиз.

### Настройка Secrets

Для работы Telegram-уведомлений добавьте в `Settings → Secrets and variables → Actions`:

| Secret | Описание |
|--------|----------|
| `TELEGRAM_BOT_TOKEN` | Токен бота (получить у [@BotFather](https://t.me/BotFather)) |
| `TELEGRAM_CHAT_ID` | ID чата для уведомлений (узнать у [@userinfobot](https://t.me/userinfobot)) |

## Благодарочка

- [tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android)
- [zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube)
- [tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy)
