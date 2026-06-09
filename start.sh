#!/bin/bash
mkdir -p /root/.junocash

# Cek WALLET_ADDRESS
if [ -z "$WALLET_ADDRESS" ]; then
  echo "❌ ERROR: WALLET_ADDRESS env var belum di-set!"
  exit 1
fi

echo "✅ Mining ke alamat: $WALLET_ADDRESS"
echo "🔄 Auto restart aktif..."

RESTART_DELAY=${RESTART_DELAY:-10}
ATTEMPT=0

while true; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "🚀 [$(date '+%Y-%m-%d %H:%M:%S')] Start attempt #$ATTEMPT"

  ./junocashd \
    -gen=1 \
    -genproclimit=${MINER_THREADS:-1} \
    -mineraddress=$WALLET_ADDRESS \
    -daemon=0 \
    -printtoconsole=1

  EXIT_CODE=$?
  echo "⚠️  [$(date '+%Y-%m-%d %H:%M:%S')] Process exited (code: $EXIT_CODE)"
  echo "⏳ Restart dalam ${RESTART_DELAY} detik..."
  sleep $RESTART_DELAY
done
