#!/usr/bin/env bash
# Builds and installs Plasma Control Centre system-wide (needs sudo for the install step).
# On Arch/CachyOS you can alternatively use: cd packaging/arch && makepkg -si
set -euo pipefail
cd "$(dirname "$0")/.."

cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build

echo
echo "Installed. Now run scripts/replace-system-tray.sh to use it in your panel,"
echo "or add it manually (see README.md)."
