#!/usr/bin/env python3
"""Immich 配置服务器 - 提供 config.html 页面并接收配置提交"""
import http.server
import json
import os
import subprocess
import sys
import tempfile
import urllib.parse


class ReuseAddrHTTPServer(http.server.HTTPServer):
    allow_reuse_address = True


class ConfigHandler(http.server.SimpleHTTPRequestHandler):
    target_dir: str = ""
    server_host: str = ""

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/config.html":
            self._serve_html()
        elif parsed.path == "/api/health":
            self._json({"status": "ok", "host": self.server_host})
        else:
            self._json({"error": "not found"}, 404)

    def do_POST(self):
        if self.path == "/api/save":
            self._handle_save()
        elif self.path == "/api/generate":
            self._handle_generate()
        elif self.path == "/api/check-r2":
            self._handle_check_r2()
        else:
            self._json({"error": "not found"}, 404)

    def _handle_check_r2(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8")
        data = json.loads(body)

        key_id = data.get("r2_access_key_id", "")
        secret = data.get("r2_secret_access_key", "")
        endpoint = data.get("r2_endpoint", "")
        bucket = data.get("r2_bucket_name", "")

        if not all([key_id, secret, endpoint, bucket]):
            self._json({"ok": False, "error": "请填写完整的 R2 配置"}, 400)
            return

        with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False) as f:
            f.write(f"""[r2]
type = s3
provider = Cloudflare
access_key_id = {key_id}
secret_access_key = {secret}
endpoint = {endpoint}
acl = private
""")
            config_path = f.name

        try:
            result = subprocess.run(
                ["rclone", "ls", f"r2:{bucket}", "--config", config_path,
                 "--max-depth", "1", "--fast-list", "--no-check-certificate"],
                capture_output=True, text=True, timeout=15
            )
            if result.returncode == 0:
                items = [l for l in result.stdout.strip().split("\n") if l]
                self._json({"ok": True, "message": f"连接成功，存储桶中有 {len(items)} 个对象"})
            else:
                err = result.stderr.strip() or "连接失败"
                self._json({"ok": False, "error": err[:300]})
        except subprocess.TimeoutExpired:
            self._json({"ok": False, "error": "连接超时，请检查 Endpoint 是否正确"})
        except FileNotFoundError:
            self._json({"ok": False, "error": "服务器未安装 rclone，请先执行 apt install rclone"})
        finally:
            os.unlink(config_path)

    def _handle_save(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8")
        data = json.loads(body)

        required = ["r2_access_key_id", "r2_secret_access_key", "r2_endpoint", "r2_bucket_name",
                    "db_username", "db_password", "db_database_name",
                    "upload_location", "db_data_location", "tz", "immich_version"]
        for key in required:
            if key not in data or not data[key]:
                self._json({"error": f"缺少必填字段: {key}"}, 400)
                return

        ext_lib1 = data.get("ext_library_1", "")
        ext_lib2 = data.get("ext_library_2", "")

        self._write_env(data)
        self._write_compose(data, ext_lib1, ext_lib2)

        self._json({"ok": True, "message": "配置已保存，可执行 docker compose up -d 启动"})

    def _handle_generate(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8")
        data = json.loads(body)

        ext_lib1 = data.get("ext_library_1", "")
        ext_lib2 = data.get("ext_library_2", "")
        env = self._render_env(data)
        compose = self._render_compose(data, ext_lib1, ext_lib2)

        self._json({"env": env, "compose": compose})

    def _write_env(self, data):
        content = self._render_env(data)
        filepath = os.path.join(self.target_dir, ".env")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)

    def _write_compose(self, data, ext_lib1, ext_lib2):
        upload = data["upload_location"]
        db_path = data["db_data_location"]
        content = self._render_compose(data, ext_lib1, ext_lib2)
        filepath = os.path.join(self.target_dir, "docker-compose.yml")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        os.makedirs(upload, exist_ok=True)
        os.makedirs(db_path, exist_ok=True)

    def _render_env(self, data):
        return f"""R2_ACCESS_KEY_ID={data['r2_access_key_id']}
R2_SECRET_ACCESS_KEY={data['r2_secret_access_key']}
R2_ENDPOINT={data['r2_endpoint']}
R2_BUCKET_NAME={data['r2_bucket_name']}
UPLOAD_LOCATION={data['upload_location']}
DB_DATA_LOCATION={data['db_data_location']}
DB_USERNAME={data['db_username']}
DB_PASSWORD={data['db_password']}
DB_DATABASE_NAME={data['db_database_name']}
REDIS_HOSTNAME=immich_redis
TZ={data['tz']}
IMMICH_VERSION={data['immich_version']}
IMMICH_MACHINE_LEARNING_URL=http://immich-machine-learning:3003
"""

    def _render_compose(self, data, ext_lib1, ext_lib2):
        upload = data["upload_location"]
        db_path = data["db_data_location"]
        ext_volumes = ""
        if ext_lib1:
            ext_volumes += f"\n      - {ext_lib1}:/mnt/library:ro"
        if ext_lib2:
            ext_volumes += f"\n      - {ext_lib2}:/mnt/pikpak:ro"

        return f"""name: immich

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
      - R2_ACCESS_KEY_ID=${{R2_ACCESS_KEY_ID}}
      - R2_SECRET_ACCESS_KEY=${{R2_SECRET_ACCESS_KEY}}
      - R2_ENDPOINT=${{R2_ENDPOINT}}
      - R2_BUCKET_NAME=${{R2_BUCKET_NAME}}
    volumes:
      - rclone-cache:/cache
      - {upload}:/data:shared
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        mkdir -p /root/.config/rclone
        cat > /root/.config/rclone/rclone.conf << RCLONE_EOF
        [r2]
        type = s3
        provider = Cloudflare
        access_key_id = $$R2_ACCESS_KEY_ID
        secret_access_key = $$R2_SECRET_ACCESS_KEY
        endpoint = $$R2_ENDPOINT
        acl = private
        RCLONE_EOF
        exec rclone mount r2:$$R2_BUCKET_NAME /data \\
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
      test: ["CMD", "rclone", "about", "r2:$$R2_BUCKET_NAME"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  immich-server:
    container_name: immich_server
    build:
      context: ../
      dockerfile: server/Dockerfile
    volumes:
      - {upload}:/data:rw
      - /etc/localtime:/etc/localtime:ro{ext_volumes}
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
    build:
      context: ../
      dockerfile: machine-learning/Dockerfile
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
      POSTGRES_PASSWORD: ${{DB_PASSWORD}}
      POSTGRES_USER: ${{DB_USERNAME}}
      POSTGRES_DB: ${{DB_DATABASE_NAME}}
      POSTGRES_INITDB_ARGS: '--data-checksums'
    volumes:
      - {db_path}:/var/lib/postgresql/data
    shm_size: 128mb
    restart: always
    healthcheck:
      disable: false

volumes:
  model-cache:
  rclone-cache:
"""

    def _serve_html(self):
        html_path = os.path.join(self.target_dir, "config.html")
        if not os.path.exists(html_path):
            self._json({"error": "config.html not found"}, 404)
            return

        with open(html_path, "r", encoding="utf-8") as f:
            content = f.read()
        content = content.replace("__API_BASE__", "")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", len(content.encode("utf-8")))
        self.end_headers()
        self.wfile.write(content.encode("utf-8"))

    def _json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", len(body))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, format, *args):
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), format % args))


def main():
    if len(sys.argv) < 2:
        print("Usage: config-server.py <target_dir> [port] [host]", file=sys.stderr)
        sys.exit(1)

    target_dir = os.path.abspath(sys.argv[1])
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080
    host = sys.argv[3] if len(sys.argv) > 3 else ""

    ConfigHandler.target_dir = target_dir
    ConfigHandler.server_host = host
    os.chdir(target_dir)

    server = ReuseAddrHTTPServer(("0.0.0.0", port), ConfigHandler)
    display_host = host or "0.0.0.0"
    print(f"配置服务器已启动: http://{display_host}:{port}/config.html", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n服务器已停止", file=sys.stderr)
        server.server_close()


if __name__ == "__main__":
    main()