#!/bin/bash
# Скрипт сборки Rust-библиотеки для Android через cargo-ndk
#
# Требования:
# - Rust: rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
# - cargo-ndk: cargo install cargo-ndk
# - Android NDK: установлен через Android Studio SDK Manager
#
# Использование:
#   ./build_android.sh
#
# Результат:
#   native/mtproto_proxy/target/
#     aarch64-linux-android/release/libmtproto_proxy.so
#     armv7-linux-androideabi/release/libmtproto_proxy.so
#     x86_64-linux-android/release/libmtproto_proxy.so
#     i686-linux-android/release/libmtproto_proxy.so

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building mtproto_proxy for Android..."

# Сборка для всех архитектур
cargo ndk \
    -t aarch64-linux-android \
    -t armv7-linux-androideabi \
    -t x86_64-linux-android \
    -t i686-linux-android \
    -o ../../android/app/src/main/jniLibs \
    build --release

echo "Build complete!"
echo "Libraries placed in: android/app/src/main/jniLibs/"
ls -la ../../android/app/src/main/jniLibs/*/libmtproto_proxy.so 2>/dev/null || echo "Check build output"