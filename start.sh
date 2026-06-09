#!/bin/bash
set -e

mkdir -p /root/.junocash

if [ -z "$WALLET_ADDRESS" ]; then
  echo "❌ ERROR: WALLET_ADDRESS env var belum di-set!"
  exit 1
fi

if [ ! -f "./junocashd" ]; then
  echo "📥 Mengambil info release terbaru dari GitHub..."

  RELEASE_JSON=$(curl -s https://api.github.com/repos/juno-cash/junocash/releases/latest)
  
  echo "=== SEMUA ASSET URL ==="
  echo "$RELEASE_JSON" | grep browser_download_url
  echo "======================"

  # Cari linux tar.gz yang BUKAN .dbg dan BUKAN SHA256
  DOWNLOAD_URL=$(echo "$RELEASE_JSON" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | grep -o 'https://[^"]*' \
    | grep -i "linux" \
    | grep "\.tar\.gz" \
    | grep -v "\.dbg" \
    | grep -v "SHA256" \
    | head -1)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "⚠️ Tidak ada linux tar.gz, coba cari semua non-dbg asset..."
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" \
      | grep -o '"browser_download_url": *"[^"]*"' \
      | grep -o 'https://[^"]*' \
      | grep -i "linux" \
      | grep -v "\.dbg" \
      | grep -v "SHA256" \
      | head -1)
  fi

  echo "📥 Downloading dari: $DOWNLOAD_URL"
  wget -q "$DOWNLOAD_URL" -O junocash_release

  echo "📦 Extracting..."
  mkdir -p extracted
  tar -xzf junocash_release -C extracted

  echo "=== ISI SETELAH EXTRACT ==="
  find extracted -type f
  echo "=========================="

  JUNOCASHD=$(find extracted -type f -name "junocashd" ! -name "*.dbg" | head -1)
  JUNOCASHCLI=$(find extracted -type f -name "junocash-cli" ! -name "*.dbg" | head -1)

  if [ -z "$JUNOCASHD" ]; then
    echo "❌ junocashd tidak ditemukan!"
    exit 1
  fi

  cp "$JUNOCASHD" ./junocashd
  [ -n "$JUNOCASHCLI" ] && cp "$JUNOCASHCLI" ./junocash-cli || true
  chmod +x junocashd
  [ -f "./junocash-cli" ] && chmod +x junocash-cli || true

  rm -rf junocash_release extracted
  echo "✅ Binary siap!"
fi

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

  echo "⚠️  [$(date '+%Y-%m-%d %H:%M:%S')] Process exited"
  echo "⏳ Restart dalam ${RESTART_DELAY} detik..."
  rm -f ./junocashd ./junocash-cli
  sleep $RESTART_DELAY
done
