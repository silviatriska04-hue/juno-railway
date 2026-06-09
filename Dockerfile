FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget curl ca-certificates tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download & extract binary Linux (nama file format tar.gz)
RUN wget -q https://github.com/juno-cash/junocash/releases/download/v0.9.9/junocash-v0.9.9-linux-x86_64.tar.gz \
    -O junocash.tar.gz \
    && tar -xzf junocash.tar.gz \
    && cp junocash-*/bin/junocashd . \
    && cp junocash-*/bin/junocash-cli . \
    && chmod +x junocashd junocash-cli \
    && rm -rf junocash.tar.gz junocash-*/

COPY start.sh .
RUN chmod +x start.sh

EXPOSE 8232 8233

CMD ["./start.sh"]
