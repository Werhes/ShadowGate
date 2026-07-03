#!/bin/bash
# Скрипт сборки Rust-библиотеки для iOS
#
# Требования:
# - Rust: rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
# - Xcode Command Line Tools
#
# Использование:
#   ./build_ios.sh
#
# Результат:
#   ios/Runner/Libraries/
#     libmtproto_proxy_device.a  (arm64 для устройств)
#     libmtproto_proxy_sim.a     (universal: arm64 + x86_64 для симулятора)
#     mtproto_proxy.h            (C header)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building mtproto_proxy for iOS..."

# Сборка для arm64 (физические устройства)
echo "=== Building for aarch64-apple-ios (device) ==="
cargo build --release --features ios --target aarch64-apple-ios

# Сборка для симулятора
echo "=== Building for aarch64-apple-ios-sim (simulator arm64) ==="
cargo build --release --features ios --target aarch64-apple-ios-sim

echo "=== Building for x86_64-apple-ios (simulator Intel) ==="
cargo build --release --features ios --target x86_64-apple-ios

# Создаём универсальную библиотеку для симулятора через lipo
echo "=== Creating universal simulator library ==="
mkdir -p target/universal-sim
lipo -create \
    target/aarch64-apple-ios-sim/release/libmtproto_proxy.a \
    target/x86_64-apple-ios/release/libmtproto_proxy.a \
    -output target/universal-sim/libmtproto_proxy.a

# Копируем в Xcode проект
echo "=== Copying to ios/Runner/Libraries/ ==="
mkdir -p ../../ios/Runner/Libraries
cp target/aarch64-apple-ios/release/libmtproto_proxy.a \
    ../../ios/Runner/Libraries/libmtproto_proxy_device.a
cp target/universal-sim/libmtproto_proxy.a \
    ../../ios/Runner/Libraries/libmtproto_proxy_sim.a
cp mtproto_proxy.h ../../ios/Runner/Libraries/

echo "=== Build complete! ==="
ls -lh ../../ios/Runner/Libraries/