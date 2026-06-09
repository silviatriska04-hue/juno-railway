#!/bin/bash
set -e

mkdir -p /root/.junocash

if [ -z "$WALLET_ADDRESS" ]; then
  echo "❌ ERROR: WALLET_ADDRESS env var belum di-set!"
  exit 1
fi

download_binary() {
  echo "📥 Mencari binary..."
  VERSIONS="v0.9.9 v0.9.8 v0.9.7"

  for VERSION in $VERSIONS; do
    echo "🔍 Coba versi $VERSION..."
    
    RELEASE_JSON=$(curl -s "https://api.github.com/repos/juno-cash/junocash/releases/tags/$VERSION")
    
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" \
      | grep -o '"browser_download_url": *"[^"]*"' \
      | grep -o 'https://[^"]*' \
      | grep -i "linux" \
      | grep "\.tar\.gz" \
      | grep -v "\.dbg" \
      | grep -v "SHA256" \
      | head -1)

    if [ -z "$DOWNLOAD_URL" ]; then
      echo "⚠️ Tidak ada binary di $VERSION, skip..."
      continue
    fi

    echo "📥 Downloading $VERSION dari: $DOWNLOAD_URL"
    wget -q "$DOWNLOAD_URL" -O junocash_release

    mkdir -p extracted
    tar -xzf junocash_release -C extracted

    JUNOCASHD=$(find extracted -type f -name "junocashd" ! -name "*.dbg" | head -1)
    
    if [ -n "$JUNOCASHD" ]; then
      echo "✅ Binary ditemukan di $VERSION!"
      JUNOCASHCLI=$(find extracted -type f -name "junocash-cli" ! -name "*.dbg" | head -1)
      cp "$JUNOCASHD" ./junocashd
      [ -n "$JUNOCASHCLI" ] && cp "$JUNOCASHCLI" ./junocash-cli || true
      chmod +x junocashd
      [ -f "./junocash-cli" ] && chmod +x junocash-cli || true
      rm -rf junocash_release extracted
      echo "✅ Binary siap! Versi: $VERSION"
      return 0
    else
      echo "⚠️ Hanya .dbg di $VERSION, skip..."
      rm -rf junocash_release extracted
    fi
  done

  echo "❌ Gagal download binary dari semua versi!"
  return 1
}

# Download hanya kalau belum ada
if [ ! -f "./junocashd" ]; then
  download_binary
fi

# Verifikasi binary ada
if [ ! -f "./junocashd" ]; then
  echo "❌ junocashd tidak ditemukan setelah download!"
  exit 1
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
  sleep $RESTART_DELAY
  # ✅ TIDAK hapus binary — langsung restart
done
