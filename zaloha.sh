#!/bin/bash

# 💾 Názov zálohy s dátumom a časom
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
TARGET_DIR="zalohy"
FILENAME="zakazky_zaloha_$TIMESTAMP.zip"

# 📁 Vytvor priečinok na zálohy, ak ešte neexistuje
mkdir -p "$TARGET_DIR"

# 📦 Vytvor ZIP s vylúčením nepotrebných zložiek
zip -r "$TARGET_DIR/$FILENAME" . -x "*.zip" "build/*" ".dart_tool/*" ".idea/*" ".git/*" "zalohy/*"

echo "✅ Záloha vytvorená: $TARGET_DIR/$FILENAME"
