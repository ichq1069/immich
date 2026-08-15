#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 支持命令行指定端口: bash setup.sh --port 9090
ARG_PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port|-p) ARG_PORT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo -e "${CYAN}"
echo "============================================="
echo "  Immich + Cloudflare R2 一键配置向导"
echo "============================================="
echo -e "${NC}"

echo "请选择配置方式:"
echo ""
echo -e "  ${GREEN}[1]${NC} 命令行交互式配置"
echo -e "  ${GREEN}[2]${NC} 网页可视化配置（推荐）"
echo ""
read -p "请输入 1 或 2 (默认: 2): " CHOICE
CHOICE=${CHOICE:-2}

if [ "$CHOICE" = "1" ]; then
  # ========== 命令行交互式 ==========
  echo -e "${YELLOW}[1/4] Cloudflare R2 存储配置${NC}"
  read -p "R2 Access Key ID: " R2_ACCESS_KEY_ID
  read -p "R2 Secret Access Key: " R2_SECRET_ACCESS_KEY
  read -p "R2 Endpoint: " R2_ENDPOINT
  read -p "R2 Bucket 名称 (默认: immich): " R2_BUCKET_NAME
  R2_BUCKET_NAME=${R2_BUCKET_NAME:-immich}

  echo -e "${YELLOW}[2/4] 存储路径配置${NC}"
  read -p "照片存储目录 (默认: /root/immich-app/r2-immich-photo): " UPLOAD_LOCATION
  UPLOAD_LOCATION=${UPLOAD_LOCATION:-/root/immich-app/r2-immich-photo}
  read -p "数据库存储目录 (默认: /root/immich-app/postgres): " DB_DATA_LOCATION
  DB_DATA_LOCATION=${DB_DATA_LOCATION:-/root/immich-app/postgres}

  echo -e "${YELLOW}[3/4] 数据库配置${NC}"
  read -p "数据库用户名 (默认: postgres): " DB_USERNAME
  DB_USERNAME=${DB_USERNAME:-postgres}
  RANDOM_PW=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16)
  read -p "数据库密码 (回车自动生成): " DB_PASSWORD
  DB_PASSWORD=${DB_PASSWORD:-$RANDOM_PW}
  read -p "数据库名 (默认: immich): " DB_DATABASE_NAME
  DB_DATABASE_NAME=${DB_DATABASE_NAME:-immich}

  echo -e "${YELLOW}[4/4] 通用配置${NC}"
  read -p "时区 (默认: Asia/Shanghai): " TZ
  TZ=${TZ:-Asia/Shanghai}
  read -p "Immich 版本 (默认: v3): " IMMICH_VERSION
  IMMICH_VERSION=${IMMICH_VERSION:-v3}

  read -p "外部图库1 路径 (可选): " EXT_LIBRARY_1
  read -p "外部图库2 路径 (可选): " EXT_LIBRARY_2

else
  # ========== 网页配置模式 ==========
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  SERVER_SCRIPT="$SCRIPT_DIR/.config-server.py"
  CONFIG_HTML="$SCRIPT_DIR/config.html"

  if [ ! -f "$CONFIG_HTML" ]; then
    echo -e "${RED}错误: 找不到 config.html，请确保文件在同目录下${NC}"
    exit 1
  fi

  # 获取服务器外网 IP
  SERVER_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || curl -s --max-time 3 ip.sb 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')

  echo ""
  if [ -n "$ARG_PORT" ]; then
    CONFIG_PORT="$ARG_PORT"
  else
    read -p "网页服务端口 (默认: 8080): " CONFIG_PORT
    CONFIG_PORT=${CONFIG_PORT:-8080}
  fi

  echo ""
  echo -e "${GREEN}============================================="
  echo "  网页配置模式已启动"
  echo "=============================================${NC}"
  echo ""
  echo -e "请在浏览器中打开:"
  echo -e "  ${CYAN}http://${SERVER_IP}:${CONFIG_PORT}/config.html${NC}"
  echo ""
  echo -e "填写配置后点击 ${YELLOW}保存到服务器${NC}，文件会自动生成到当前目录"
  echo ""
  echo -e "按 ${RED}Ctrl+C${NC} 停止服务"
  echo ""

  # 启动 Python 配置服务器
  python3 "$SERVER_SCRIPT" "$SCRIPT_DIR" "$CONFIG_PORT"
  exit 0
fi

# ========== 生成配置文件（命令行模式） ==========
_generate_files() {
  local UPLOAD_LOCATION="$1"
  local DB_DATA_LOCATION="$2"
  local DB_USERNAME="$3"
  local DB_PASSWORD="$4"
  local DB_DATABASE_NAME="$5"
  local TZ="$6"
  local IMMICH_VERSION="$7"
  local R2_ACCESS_KEY_ID="$8"
  local R2_SECRET_ACCESS_KEY="$9"
  local R2_ENDPOINT="${10}"
  local R2_BUCKET_NAME="${11}"
  local EXT_LIBRARY_1="${12}"
  local EXT_LIBRARY_2="${13}"

  cat > .env << ENV_EOF
R2_ACCESS_KEY_ID=${R2_ACCESS_KEY_ID}
R2_SECRET_ACCESS_KEY=${R2_SECRET_ACCESS_KEY}
R2_ENDPOINT=${R2_ENDPOINT}
R2_BUCKET_NAME=${R2_BUCKET_NAME}
UPLOAD_LOCATION=${UPLOAD_LOCATION}
DB_DATA_LOCATION=${DB_DATA_LOCATION}
DB_USERNAME=${DB_USERNAME}
DB_PASSWORD=${DB_PASSWORD}
DB_DATABASE_NAME=${DB_DATABASE_NAME}
REDIS_HOSTNAME=immich_redis
TZ=${TZ}
IMMICH_VERSION=${IMMICH_VERSION}
IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
ENV_EOF

  local EXT_VOLUMES=""
  [ -n "$EXT_LIBRARY_1" ] && EXT_VOLUMES="${EXT_VOLUMES}\n      - ${EXT_LIBRARY_1}:/mnt/library:ro"
  [ -n "$EXT_LIBRARY_2" ] && EXT_VOLUMES="${EXT_VOLUMES}\n      - ${EXT_LIBRARY_2}:/mnt/pikpak:ro"

  cat > docker-compose.yml << COMPOSE_EOF
name: immich

services:
  rclone:
    image: rclone/rclone:1.70
    container_name: immich_rclone
    privileged: true
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    devices:
      - /dev/fuse:/dev/fuse
    environment:
      - R2_ACCESS_KEY_ID=\${R2_ACCESS_KEY_ID}
      - R2_SECRET_ACCESS_KEY=\${R2_SECRET_ACCESS_KEY}
      - R2_ENDPOINT=\${R2_ENDPOINT}
      - R2_BUCKET_NAME=\${R2_BUCKET_NAME}
    volumes:
      - rclone-cache:/cache
      - ${UPLOAD_LOCATION}:/data:shared
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        mkdir -p /root/.config/rclone
        cat > /root/.config/rclone/rclone.conf << RCLONE_EOF
        [r2]
        type = s3
        provider = Cloudflare
        access_key_id = \$\$R2_ACCESS_KEY_ID
        secret_access_key = \$\$R2_SECRET_ACCESS_KEY
        endpoint = \$\$R2_ENDPOINT
        acl = private
        RCLONE_EOF
        exec rclone mount r2:\$\$R2_BUCKET_NAME /data \\
          --allow-other \\
          --allow-non-empty \\
          --vfs-cache-mode writes \\
          --vfs-cache-max-age 1h \\
          --vfs-cache-max-size 10G \\
          --cache-dir /cache \\
          --dir-cache-time 5m \\
          --no-checksum \\
          --log-level INFO
    restart: always
    healthcheck:
      test: ["CMD", "rclone", "about", "r2:\$\$R2_BUCKET_NAME"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  immich-server:
    container_name: immich_server
    image: ghcr.io/immich-app/immich-server:\${IMMICH_VERSION:-release}
    volumes:
      - ${UPLOAD_LOCATION}:/data:rw
      - /etc/localtime:/etc/localtime:ro$(echo -e "$EXT_VOLUMES")
    env_file:
      - .env
    ports:
      - '2283:2283'
    depends_on:
      rclone:
        condition: service_healthy
      redis:
        condition: service_started
      database:
        condition: service_started
    restart: always
    healthcheck:
      disable: false

  immich-machine-learning:
    container_name: immich_machine_learning
    image: ghcr.io/immich-app/immich-machine-learning:\${IMMICH_VERSION:-release}
    volumes:
      - model-cache:/cache
    env_file:
      - .env
    restart: always
    healthcheck:
      disable: false

  redis:
    container_name: immich_redis
    image: docker.io/valkey/valkey:9@sha256:4963247afc4cd33c7d3b2d2816b9f7f8eeebab148d29056c2ca4d7cbc966f2d9
    healthcheck:
      test: redis-cli ping || exit 1
    restart: always

  database:
    container_name: immich_postgres
    image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23
    environment:
      POSTGRES_PASSWORD: \${DB_PASSWORD}
      POSTGRES_USER: \${DB_USERNAME}
      POSTGRES_DB: \${DB_DATABASE_NAME}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
    shm_size: 128mb
    restart: always
    healthcheck:
      disable: false

volumes:
  model-cache:
  rclone-cache:
COMPOSE_EOF

  mkdir -p "$UPLOAD_LOCATION" "$DB_DATA_LOCATION"
}

_generate_files \
  "$UPLOAD_LOCATION" "$DB_DATA_LOCATION" "$DB_USERNAME" "$DB_PASSWORD" \
  "$DB_DATABASE_NAME" "$TZ" "$IMMICH_VERSION" \
  "$R2_ACCESS_KEY_ID" "$R2_SECRET_ACCESS_KEY" "$R2_ENDPOINT" "$R2_BUCKET_NAME" \
  "$EXT_LIBRARY_1" "$EXT_LIBRARY_2"

echo ""
echo -e "${GREEN}============================================="
echo "  配置完成！"
echo "=============================================${NC}"
echo ""
echo -e "数据库密码: ${GREEN}${DB_PASSWORD}${NC}"
echo -e "启动命令:   ${YELLOW}docker compose up -d${NC}"
echo -e "访问地址:   ${CYAN}http://服务器IP:2283${NC}"