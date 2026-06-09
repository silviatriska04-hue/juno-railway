FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget curl ca-certificates tar jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY start.sh .
RUN chmod +x start.sh

EXPOSE 8232 8233

CMD ["./start.sh"]
