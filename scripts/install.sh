#!/bin/bash

set -e

echo "=== Установка 3xui-shop с Caddy (без Traefik) ==="

INSTALL_DIR="/home/vp2025/3xui-shop"

if [ -n "$1" ]; then
  INSTALL_DIR="$1"
fi

echo "Директория установки: $INSTALL_DIR"

if [ -d "$INSTALL_DIR/.git" ]; then
  echo "Репозиторий уже существует, обновляю..."
  cd "$INSTALL_DIR"
  git pull
else
  echo "Клонирую репозиторий..."
  git clone https://github.com/johnnybegood24/3xui-shop "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

read -rp "Введите домен для бота (например, bot.vpnhostess.uk): " BOT_DOMAIN

if [ -z "$BOT_DOMAIN" ]; then
  echo "Домен не указан, выхожу."
  exit 1
fi

echo "Использую домен: $BOT_DOMAIN"

if [ ! -f ".env" ]; then
  if [ -f ".env.example" ]; then
    echo "Создаю .env из .env.example..."
    cp .env.example .env
  else
    echo "Файл .env.example не найден, создаю пустой .env..."
    touch .env
  fi
fi

if grep -q "^BOT_DOMAIN=" .env; then
  sed -i "s|^BOT_DOMAIN=.*|BOT_DOMAIN=https://$BOT_DOMAIN|" .env
else
  echo "BOT_DOMAIN=https://$BOT_DOMAIN" >> .env
fi

echo "BOT_DOMAIN установлен: https://$BOT_DOMAIN"

cat > docker-compose.yml <<EOF
services:
  bot:
    build: .
    container_name: 3xui-shop-bot
    env_file:
      - .env
    restart: always
    networks:
      - shopnet

networks:
  shopnet:
EOF

cat > docker-compose.caddy.yml <<EOF
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - shopnet

networks:
  shopnet:

volumes:
  caddy_data:
  caddy_config:
EOF

cat > Caddyfile <<EOF
$BOT_DOMAIN {
    reverse_proxy 3xui-shop-bot:8080
}
EOF

docker compose -f docker-compose.yml -f docker-compose.caddy.yml up -d --build

echo "=== Установка завершена ==="
echo "Бот доступен по адресу: https://$BOT_DOMAIN"
echo "Traefik отключён. Используется Caddy."
