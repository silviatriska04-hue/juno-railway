#!/bin/bash
set -e

mkdir -p /root/.junocash

# === Cek WALLET_ADDRESS ===
if [ -z "$WALLET_ADDRESS" ]; then
  echo "❌ ERROR: WALLET_ADDRESS env var belum di-set!"
  exit 1
fi

# === Download binary kalau belum ada ===
if [ ! -f "./junocashd" ]; then
  echo "📥 Mengambil info release terbaru dari GitHub..."

  # Ambil URL download dari GitHub API
  RELEASE_JSON=$(curl -s https://api.github.com/repos/juno-cash/junocash/releases/latest)
  
  # Cari asset linux
  DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*linux[^"]*\.tar\.gz"' | grep -o 'https://[^"]*' | head -1)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Gagal menemukan URL download Linux binary!"
    echo "$RELEASE_JSON" | grep browser_download_url
    exit 1
  fi

  echo "📥 Downloading dari: $DOWNLOAD_URL"
  wget -q "$DOWNLOAD_URL" -O junocash.tar.gz

  echo "📦 Extracting..."
  tar -xzf junocash.tar.gz
  cp junocash-*/bin/junocashd . 2>/dev/null || cp */junocashd . 2>/dev/null || true
  cp junocash-*/bin/junocash-cli . 2>/dev/null || cp */junocash-cli . 2>/dev/null || true
  chmod +x junocashd junocash-cli
  rm -rf junocash.tar.gz junocash-*/
  echo "✅ Binary siap!"
fi

# === Auto Restart Loop ===
RESTART_DELAY=${RESTART_DELAY:-10}
ATTEMPT=0

echo "✅ Mining ke alamat: $WALLET_ADDRESS"
echo "🔄 Auto restart aktif..."

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "🚀 [$(date '+%Y-%m-%d %H:%M:%S')] Start attempt #$ATTEMPT"

  ./junocashd \
    -gen=1 \
    -genproclimit=${MINER_THREADS:-1} \
    -mineraddress=$WALLET_ADDRESS \
    -daemon=0 \
    -printtoconsole=1 || true

  EXIT_CODE=$?
  echo "⚠️  [$(date '+%Y-%m-%d %H:%M:%S')] Process exited (code: $EXIT_CODE)"
  echo "⏳ Restart dalam ${RESTART_DELAY} detik..."
  sleep $RESTART_DELAY
done
