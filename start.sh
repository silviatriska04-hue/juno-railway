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
  
  DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*linux[^"]*\.tar\.gz"' | grep -o 'https://[^"]*' | head -1)

  if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Gagal menemukan URL download!"
    exit 1
  fi

  echo "📥 Downloading dari: $DOWNLOAD_URL"
  wget -q "$DOWNLOAD_URL" -O junocash.tar.gz

  echo "📦 Extracting..."
  tar -xzf junocash.tar.gz

  echo "🔍 Isi folder setelah extract:"
  find . -name "junocashd" -o -name "junocash-cli" 2>/dev/null

  # Cari binary di semua subfolder
  JUNOCASHD=$(find . -name "junocashd" -type f | head -1)
  JUNOCASHCLI=$(find . -name "junocash-cli" -type f | head -1)

  if [ -z "$JUNOCASHD" ]; then
    echo "❌ junocashd tidak ditemukan setelah extract!"
    ls -la
    exit 1
  fi

  cp "$JUNOCASHD" ./junocashd
  [ -n "$JUNOCASHCLI" ] && cp "$JUNOCASHCLI" ./junocash-cli

  chmod +x junocashd
  [ -f "./junocash-cli" ] && chmod +x junocash-cli

  rm -rf junocash.tar.gz
  # Hapus folder extract
  find . -maxdepth 1 -type d ! -name "." | grep -v "^\.$" | xargs rm -rf

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

  echo "⚠️  [$(date '+%Y-%m-%d %H:%M:%S')] Process exited"
  echo "⏳ Restart dalam ${RESTART_DELAY} detik..."

  # Hapus binary biar download ulang versi terbaru
  rm -f ./junocashd ./junocash-cli

  sleep $RESTART_DELAY
done
