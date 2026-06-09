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

  DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*linux[^"]*\.tar\.gz"' | grep -o 'https://[^"]*' | head -1)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Tidak ada .tar.gz linux, coba cari semua asset..."
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*linux[^"]*"' | grep -o 'https://[^"]*' | head -1)
  fi

  echo "📥 Downloading dari: $DOWNLOAD_URL"
  wget -q "$DOWNLOAD_URL" -O junocash_release

  echo "=== TIPE FILE ==="
  file junocash_release

  # Cek apakah tar.gz atau file tunggal
  if file junocash_release | grep -q "gzip\|tar"; then
    echo "📦 Extracting tar.gz..."
    mkdir -p extracted
    tar -xzf junocash_release -C extracted

    echo "=== ISI SETELAH EXTRACT ==="
    find extracted -type f
    echo "=========================="

    JUNOCASHD=$(find extracted -name "junocashd" -type f | head -1)
    JUNOCASHCLI=$(find extracted -name "junocash-cli" -type f | head -1)
  else
    echo "📄 File tunggal (bukan tar.gz), coba langsung pakai..."
    cp junocash_release junocashd
    chmod +x junocashd
    JUNOCASHD="./junocashd"
  fi

  if [ -z "$JUNOCASHD" ]; then
    echo "❌ junocashd tidak ditemukan!"
    echo "=== SEMUA FILE DI EXTRACTED ==="
    find extracted -type f -ls 2>/dev/null || ls -la
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
