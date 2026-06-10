#!/bin/bash
set -e

mkdir -p /root/.junocash

SHIELD_ADDRESS=${WALLET_ADDRESS:-"j1ym7fsw83rln2r4h2e24gs6q2hjc5mguxl2j7ukejtwrw4wh8sw5zhx5sfev3et7nuwx20pwmre54k66ahvqdfvlvzarwvt7luv4zkt5q"}
MINING_ADDRESS=${MINING_ADDRESS:-"t1Jegz7mFagQSX2cRkkeTktgiisviZmCjta"}

# Tulis config file
cat > /root/.junocash/junocashd.conf << CONF
mineraddress=$MINING_ADDRESS
minetolocalwallet=0
gen=1
genproclimit=${MINER_THREADS:-1}
onlynet=ipv4
daemon=0
printtoconsole=1
addnode=junopool.com
addnode=junohash.com
addnode=juno.suprnova.cc
addnode=juno-cash.minerlab.io
CONF

echo "📝 Config written:"
cat /root/.junocash/junocashd.conf

download_binary() {
  echo "📥 Mencari binary..."

  LATEST=$(curl -s "https://api.github.com/repos/juno-cash/junocash/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | grep -o 'v[^"]*' | head -1)

  if [ -n "$LATEST" ]; then
    VERSIONS="$LATEST v0.9.9 v0.9.8 v0.9.7"
  else
    VERSIONS="v0.9.9 v0.9.8 v0.9.7"
  fi

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

auto_shield() {
  echo "🛡️ Auto-shield thread aktif, cek setiap 10 menit..."
  sleep 300

  while true; do
    BALANCE=$(./junocash-cli getbalance 2>/dev/null || echo "0")
    HEIGHT=$(./junocash-cli getblockcount 2>/dev/null || echo "?")
    echo "💰 [$(date '+%H:%M:%S')] Height: $HEIGHT | Balance: $BALANCE JNO"

    if awk "BEGIN {exit !($BALANCE > 0)}"; then
      echo "🛡️ Shielding $BALANCE JNO ke $SHIELD_ADDRESS ..."
      ./junocash-cli z_shieldcoinbase "*" "$SHIELD_ADDRESS" 0.0001 2>&1 || echo "⚠️ Shield gagal, coba lagi nanti..."
    fi

    sleep 600
  done
}

if [ ! -f "./junocashd" ]; then
  download_binary
fi

if [ ! -f "./junocashd" ]; then
  echo "❌ junocashd tidak ditemukan!"
  exit 1
fi

RESTART_DELAY=${RESTART_DELAY:-10}
ATTEMPT=0

echo "🚀 Junocash Mining Node Starting..."
echo "🛡️ Shield address: $SHIELD_ADDRESS"
echo "⛏️  Mining address: $MINING_ADDRESS"
echo "🔄 Auto restart aktif..."

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "🚀 [$(date '+%Y-%m-%d %H:%M:%S')] Start attempt #$ATTEMPT"

  ./junocashd &
  NODE_PID=$!
  auto_shield &
  SHIELD_PID=$!

  wait $NODE_PID || true
  kill $SHIELD_PID 2>/dev/null || true

  echo "⚠️  [$(date '+%Y-%m-%d %H:%M:%S')] Process exited"
  echo "⏳ Restart dalam ${RESTART_DELAY} detik..."
  sleep $RESTART_DELAY
done
