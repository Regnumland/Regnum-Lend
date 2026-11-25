#!/bin/bash
# Збірка проби під браузер: build/godot-web/ (index.html, index.js, index.wasm, index.pck)
set -e; cd "$(dirname "$0")"
G=${GODOT:-godot}
mkdir -p ../../build/godot-web
$G --headless --import . >/dev/null 2>&1 || true
$G --headless --export-release "Web" ../../build/godot-web/index.html 2>&1 | grep -iE "^ERROR|SCRIPT ERROR" || true
ls -la ../../build/godot-web
