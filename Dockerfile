FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download junocashd Linux binary (v0.9.9 latest)
RUN wget -q https://github.com/juno-cash/junocash/releases/download/v0.9.9/junocashd-linux \
    -O junocashd && chmod +x junocashd

COPY start.sh .
RUN chmod +x start.sh

EXPOSE 8332 8333

CMD ["./start.sh"]
