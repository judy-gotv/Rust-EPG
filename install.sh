#!/usr/bin/env bash
# ============================================================
#  EPG 系统 - 一键远程安装脚本
# ------------------------------------------------------------
#  用法:
#    curl -fsSL https://raw.githubusercontent.com/judy-gotv/Rust-EPG/main/install.sh | bash
#    或
#    wget -qO- https://raw.githubusercontent.com/judy-gotv/Rust-EPG/main/install.sh | bash
#
#  非交互一键模式:
#    curl -fsSL ... | bash -s install      # 直接安装+启动
#    curl -fsSL ... | bash -s uninstall    # 直接卸载
# ============================================================
set -e

# ---------------- 配色 ----------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERR ]${NC} $*"; exit 1; }
step()  { echo -e "${MAGENTA}[STEP]${NC} ${BOLD}$*${NC}"; }

# ---------------- 默认配置 ----------------
EPG_DIR="${EPG_DIR:-/opt/epg}"                # 数据目录
INSTALL_DIR="${INSTALL_DIR:-/opt/epg/app}"    # 安装目录（二进制/前端）
BACKEND_PORT="${BACKEND_PORT:-8080}"
FRONTEND_PORT="${FRONTEND_PORT:-8081}"
DEFAULT_USER="${EPG_DEFAULT_USER:-admin}"
DEFAULT_PASS="${EPG_DEFAULT_PASS:-admin123}"
HTPASSWD_PATH="${EPG_HTPASSWD_PATH:-$EPG_DIR/epg.htpasswd}"

# GitHub 下载地址 (Releases - latest 自动指向最新版本)
GH_REPO="judy-gotv/Rust-EPG"
GH_RELEASE_TAG="${GH_RELEASE_TAG:-latest}"   # 可指定具体版本号，如 0.0.1
if [ "$GH_RELEASE_TAG" = "latest" ]; then
  GH_BASE="https://github.com/${GH_REPO}/releases/latest/download"
else
  GH_BASE="https://github.com/${GH_REPO}/releases/download/${GH_RELEASE_TAG}"
fi
URL_AMD64="${GH_BASE}/epg-linux-amd64.tar.gz"
URL_ARM64="${GH_BASE}/epg-linux-arm64.tar.gz"
URL_ARMV7="${GH_BASE}/epg-linux-armv7.tar.gz"

# ---------------- sudo 检测 ----------------
SUDO=""
if [ "$(id -u)" != "0" ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    error "当前非 root 用户且未安装 sudo，请用 root 执行或安装 sudo"
  fi
fi

# ---------------- 架构检测 ----------------
detect_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64|amd64)        echo "amd64" ;;
    aarch64|arm64)       echo "arm64" ;;
    armv7l|armv7|armhf)  echo "armv7" ;;
    *)                   echo "unknown" ;;
  esac
}

arch_url() {
  case "$1" in
    amd64) echo "$URL_AMD64" ;;
    arm64) echo "$URL_ARM64" ;;
    armv7) echo "$URL_ARMV7" ;;
    *)     echo "" ;;
  esac
}

# ---------------- 工具：包管理器抽象 ----------------
PM=""
detect_pm() {
  if   command -v apt-get >/dev/null 2>&1; then PM="apt"
  elif command -v dnf     >/dev/null 2>&1; then PM="dnf"
  elif command -v yum     >/dev/null 2>&1; then PM="yum"
  elif command -v apk     >/dev/null 2>&1; then PM="apk"
  elif command -v pacman  >/dev/null 2>&1; then PM="pacman"
  elif command -v zypper  >/dev/null 2>&1; then PM="zypper"
  else PM="unknown"
  fi
}

pkg_install() {
  # $@ : 包名（按 PM 顺序: apt dnf yum apk pacman zypper）
  # 用法: pkg_install apt:apache2-utils dnf:httpd-tools yum:httpd-tools apk:apache2-utils pacman:apache zypper:apache2-utils
  detect_pm
  local pkg=""
  for spec in "$@"; do
    if [ "${spec%%:*}" = "$PM" ]; then
      pkg="${spec#*:}"
      break
    fi
  done
  [ -z "$pkg" ] && { warn "未识别的包管理器 ($PM)，跳过"; return 0; }
  case "$PM" in
    apt)    $SUDO apt-get update -y >/dev/null 2>&1 || true; $SUDO apt-get install -y $pkg ;;
    dnf)    $SUDO dnf install -y $pkg ;;
    yum)    $SUDO yum install -y $pkg ;;
    apk)    $SUDO apk add --no-cache $pkg ;;
    pacman) $SUDO pacman -Sy --noconfirm $pkg ;;
    zypper) $SUDO zypper install -y $pkg ;;
  esac
}

ensure_cmd() {
  # ensure_cmd <command> <pkg-spec...>
  local cmd="$1"; shift
  if command -v "$cmd" >/dev/null 2>&1; then return 0; fi
  warn "缺少命令 $cmd，正在自动安装..."
  pkg_install "$@"
  command -v "$cmd" >/dev/null 2>&1 || warn "$cmd 仍未安装，可能影响后续步骤"
}

# ---------------- 基础依赖 ----------------
prepare_basics() {
  step "检查基础工具 (curl/tar/htpasswd/python3) ..."
  ensure_cmd curl     apt:curl dnf:curl yum:curl apk:curl pacman:curl zypper:curl
  ensure_cmd tar      apt:tar  dnf:tar  yum:tar  apk:tar  pacman:tar  zypper:tar
  ensure_cmd htpasswd apt:apache2-utils dnf:httpd-tools yum:httpd-tools apk:apache2-utils pacman:apache zypper:apache2-utils
  ensure_cmd nginx    apt:nginx dnf:nginx yum:nginx apk:nginx pacman:nginx zypper:nginx
}

# ---------------- 准备目录 ----------------
prepare_dirs() {
  step "准备目录 $EPG_DIR ..."
  $SUDO mkdir -p "$EPG_DIR"/{data,logs,conf} "$INSTALL_DIR"
  local U G
  U="$(id -un)"; G="$(id -gn)"
  $SUDO chown -R "$U:$G" "$EPG_DIR" 2>/dev/null || true
  $SUDO chmod -R 755 "$EPG_DIR" 2>/dev/null || true
  log "  - $EPG_DIR (owner=$U:$G, mode=755) ✅"
}

# ---------------- 下载并解压 ----------------
download_pkg() {
  local arch="$1"
  local url; url="$(arch_url "$arch")"
  [ -z "$url" ] && error "不支持的架构: $arch"

  step "下载 $arch 二进制包 ..."
  log "  - URL: $url"
  local tmp="/tmp/epg-linux-$arch.tar.gz"
  rm -f "$tmp"
  if ! curl -fL --progress-bar -o "$tmp" "$url"; then
    error "下载失败，请检查网络或 GitHub 是否可访问"
  fi
  log "  - 已下载: $(du -h "$tmp" | cut -f1) -> $tmp"

  step "解压到 $INSTALL_DIR ..."
  local extract_tmp="/tmp/epg-extract-$$"
  rm -rf "$extract_tmp"; mkdir -p "$extract_tmp"
  tar xzf "$tmp" -C "$extract_tmp"
  # 包内根目录名为 epg-linux-<arch>
  local pkgdir="$extract_tmp/epg-linux-$arch"
  [ -d "$pkgdir" ] || pkgdir="$(find "$extract_tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
  [ -d "$pkgdir" ] || error "解压后未找到包目录"

  # 备份旧 config（保留用户修改）
  [ -f "$INSTALL_DIR/config.yml" ] && cp "$INSTALL_DIR/config.yml" "$INSTALL_DIR/config.yml.bak.$(date +%s)" || true

  # 复制文件（覆盖二进制和前端，保留 config 备份）
  $SUDO mkdir -p "$INSTALL_DIR"
  $SUDO cp -rf "$pkgdir"/* "$INSTALL_DIR/"
  $SUDO chmod +x "$INSTALL_DIR/epg-server" "$INSTALL_DIR/run.sh" 2>/dev/null || true

  rm -rf "$extract_tmp" "$tmp"
  log "  - 已安装到 $INSTALL_DIR ✅"
}

# ---------------- 初始化账号 ----------------
init_account() {
  step "初始化默认账号 ..."
  if [ -f "$HTPASSWD_PATH" ]; then
    log "  - 已存在: $HTPASSWD_PATH ✅ (跳过)"
    return
  fi
  if command -v htpasswd >/dev/null 2>&1; then
    htpasswd -bcB "$HTPASSWD_PATH" "$DEFAULT_USER" "$DEFAULT_PASS" >/dev/null 2>&1 \
      || $SUDO htpasswd -bcB "$HTPASSWD_PATH" "$DEFAULT_USER" "$DEFAULT_PASS" >/dev/null 2>&1
    log "  - 已创建: $DEFAULT_USER / $DEFAULT_PASS -> $HTPASSWD_PATH"
  else
    warn "  - 未安装 htpasswd，跳过账号创建"
  fi
}

# ---------------- 停止旧进程 ----------------
stop_services() {
  step "停止旧服务 ..."
  for pidf in "$INSTALL_DIR/logs/server.pid"; do
    if [ -f "$pidf" ]; then
      local pid; pid="$(cat "$pidf" 2>/dev/null || true)"
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        log "  - 已停止后端 PID=$pid"
      fi
      rm -f "$pidf"
    fi
  done
  pkill -f "$INSTALL_DIR/epg-server" 2>/dev/null || true

  # 停止 nginx 中 EPG 站点（保留 nginx 本身）
  if [ -f /etc/nginx/conf.d/epg.conf ] || [ -f /etc/nginx/sites-enabled/epg ]; then
    log "  - 重载 nginx (移除 EPG 配置后需要手动 stop_nginx_site)"
  fi
}

# ---------------- 检测 nginx 配置目录 ----------------
nginx_conf_target() {
  if [ -d /etc/nginx/conf.d ]; then
    echo "/etc/nginx/conf.d/epg.conf"
  elif [ -d /etc/nginx/sites-enabled ]; then
    echo "/etc/nginx/sites-enabled/epg.conf"
  elif [ -d /etc/nginx/http.d ]; then
    echo "/etc/nginx/http.d/epg.conf"
  else
    echo "/etc/nginx/conf.d/epg.conf"
  fi
}

# ---------------- 生成 nginx 站点配置 ----------------
setup_nginx() {
  step "配置 nginx (反向代理 + 静态前端) ..."
  local conf; conf="$(nginx_conf_target)"
  local web_root="$INSTALL_DIR/web"

  # 升级时备份旧配置，便于回滚
  if [ -f "$conf" ]; then
    $SUDO cp -a "$conf" "${conf}.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  fi

  # 确保 nginx 能读到目录
  $SUDO chmod 755 "$INSTALL_DIR" 2>/dev/null || true
  $SUDO chmod -R a+rX "$web_root" 2>/dev/null || true

  $SUDO mkdir -p "$(dirname "$conf")"
  $SUDO tee "$conf" >/dev/null <<EOF
# EPG 系统 nginx 站点 - 由 install.sh 生成
# 仅监听独立端口 ${FRONTEND_PORT}，不抢占 80/443，方便未来挂域名 + HTTPS 反代
server {
    listen ${FRONTEND_PORT};
    listen [::]:${FRONTEND_PORT};
    server_name _;

    # 上传体积 (XMLTV / m3u 可能较大)
    client_max_body_size 50m;

    root ${web_root};
    index index.html;

    # 前端 SPA 路由 fallback (必须放在所有 API/导出 location 之后)
    # 公开 API、管理 API、导出路由都在前面优先匹配

    # ⚠️ 管理 API - 由后端做登录鉴权（cookie + token），nginx 不再 auth_basic
    location /api/v1/admin {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Cookie \$http_cookie;
        proxy_set_header Authorization \$http_authorization;
        proxy_read_timeout 300s;
    }

    # 登录接口（公开）
    location /api/v1/auth {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Cookie \$http_cookie;
        proxy_set_header Authorization \$http_authorization;
        proxy_read_timeout 60s;
    }

    # 公开 API
    location /api/ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }

    # 健康检查 / Prometheus 指标
    location ~ ^/(health|metrics)\$ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_set_header Host \$host;
    }

    # EPG 导出 - XMLTV / DIYP（IPTV 播放器订阅地址）
    location ~ ^/(epg\.xml|epg\.xml\.gz|e\.xml|e\.xml\.gz|diyp|epg/diyp)\$ {
        proxy_pass http://127.0.0.1:${BACKEND_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }

    # 前端 SPA - 兜底（必须最后）
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
  log "  - 已写入 $conf (仅占用端口 ${FRONTEND_PORT}, 不影响 80/443)"

  # 生成域名反代示例 (不自动启用，供用户参考)
  local example="$EPG_DIR/nginx-domain-example.conf"
  $SUDO tee "$example" >/dev/null <<EOF
# ============================================================
# EPG 域名反代示例 (HTTP 80 + HTTPS 443)
# 用法:
#   1) 把本文件复制到 /etc/nginx/conf.d/epg-domain.conf
#   2) 修改 server_name 为你的真实域名
#   3) 用 certbot 申请 HTTPS 证书:
#        certbot --nginx -d epg.example.com
#   4) nginx -t && nginx -s reload
# ============================================================

# HTTP -> HTTPS 跳转
server {
    listen 80;
    listen [::]:80;
    server_name epg.example.com;
    return 301 https://\$host\$request_uri;
}

# HTTPS
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name epg.example.com;

    # 证书路径 (certbot 申请后会自动注入)
    # ssl_certificate     /etc/letsencrypt/live/epg.example.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/epg.example.com/privkey.pem;

    client_max_body_size 50m;

    # 整站反代到 EPG nginx 内部站点
    location / {
        proxy_pass http://127.0.0.1:${FRONTEND_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }
}
EOF
  log "  - 域名反代示例: $example (按需启用)"

  # 测试配置并 reload
  if $SUDO nginx -t >/dev/null 2>&1; then
    if pgrep -x nginx >/dev/null 2>&1; then
      $SUDO nginx -s reload && log "  - nginx 已 reload ✅"
    else
      $SUDO nginx && log "  - nginx 已启动 ✅"
      command -v systemctl >/dev/null && $SUDO systemctl enable nginx >/dev/null 2>&1 || true
    fi
  else
    warn "  - nginx 配置测试失败，请检查："
    $SUDO nginx -t
  fi
}

# ---------------- 移除 nginx 站点 ----------------
remove_nginx_site() {
  local conf; conf="$(nginx_conf_target)"
  [ -f "$conf" ] && { $SUDO rm -f "$conf"; log "  - 已移除 $conf"; }
  if pgrep -x nginx >/dev/null 2>&1; then
    $SUDO nginx -t >/dev/null 2>&1 && $SUDO nginx -s reload || true
  fi
}

# ---------------- 启动服务 ----------------
start_services() {
  step "启动后端服务 ..."
  mkdir -p "$INSTALL_DIR/logs"
  # 软链 data -> EPG_DIR/data，让二进制读到 ./data/epg.db
  ln -sfn "$EPG_DIR/data" "$INSTALL_DIR/data" 2>/dev/null || $SUDO ln -sfn "$EPG_DIR/data" "$INSTALL_DIR/data"

  # ⚠️ 强制后端只绑定 127.0.0.1（安全：后端无鉴权，必须由 nginx 拦截）
  if [ -f "$INSTALL_DIR/config.yml" ]; then
    if grep -q 'host: "0.0.0.0"' "$INSTALL_DIR/config.yml" 2>/dev/null; then
      $SUDO sed -i 's/host: "0.0.0.0"/host: "127.0.0.1"/' "$INSTALL_DIR/config.yml"
      warn "  - 已将后端绑定改为 127.0.0.1 (避免裸奔)"
    fi
  fi

  cd "$INSTALL_DIR"
  EPG_HTPASSWD_PATH="$HTPASSWD_PATH" \
    nohup ./epg-server > "$INSTALL_DIR/logs/server.log" 2>&1 &
  local spid=$!
  echo $spid > "$INSTALL_DIR/logs/server.pid"
  log "  - 后端 PID=$spid (监听 127.0.0.1:${BACKEND_PORT}, 仅本机, 由 nginx 反代)"

  # 前端由 nginx 托管 + 反代 API
  setup_nginx
  sleep 2
}

# ---------------- 完成横幅 ----------------
print_banner() {
  local arch="$1"
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  [ -z "$ip" ] && ip="$(hostname -i 2>/dev/null | awk '{print $1}')"
  [ -z "$ip" ] && ip="<服务器 IP>"

  echo
  echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║   ✅  EPG 系统安装并启动完成 (${arch})       ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
  echo -e "  ${BOLD}访问地址 (nginx 已托管前端 + 反代 API)${NC}"
  echo -e "    前端首页 : ${CYAN}http://${ip}:${FRONTEND_PORT}${NC}"
  echo -e "    登录页面 : ${CYAN}${BOLD}http://${ip}:${FRONTEND_PORT}/login${NC}   👈 美化登录入口"
  echo -e "    后台管理 : ${CYAN}http://${ip}:${FRONTEND_PORT}/admin${NC} (未登录自动跳 /login)"
  echo -e "    后端健康 : ${CYAN}http://${ip}:${FRONTEND_PORT}/health${NC}"
  echo -e "  ${BOLD}目录${NC}"
  echo -e "    安装目录 : ${INSTALL_DIR}"
  echo -e "    数据目录 : ${EPG_DIR}"
  echo -e "    nginx    : $(nginx_conf_target)"
  echo -e "    日志     : ${INSTALL_DIR}/logs/server.log"
  echo -e "${GREEN}--------------------------------------------${NC}"
  echo -e "  🔐  ${YELLOW}${BOLD}默认登录账号${NC}"
  echo -e "      用户名 : ${CYAN}${BOLD}${DEFAULT_USER}${NC}"
  echo -e "      密  码 : ${CYAN}${BOLD}${DEFAULT_PASS}${NC}"
  echo -e "      文件   : ${HTPASSWD_PATH}"
  echo -e "  ⚠️   ${YELLOW}首次登录后请立即在后台修改密码！${NC}"
  echo -e "${GREEN}--------------------------------------------${NC}"
  echo -e "  ${BOLD}常用命令${NC} (后续管理直接调用安装目录内 run.sh)"
  echo -e "    ${INSTALL_DIR}/run.sh menu        # 交互菜单"
  echo -e "    ${INSTALL_DIR}/run.sh start|stop|status|uninstall"
  echo -e "    或重新运行本脚本: ${CYAN}bash $0${NC}"
  echo -e "${GREEN}============================================${NC}"
}

# ---------------- 主动作 ----------------
do_install() {
  local arch="${1:-}"
  if [ -z "$arch" ] || [ "$arch" = "auto" ]; then
    arch="$(detect_arch)"
    [ "$arch" = "unknown" ] && error "无法识别架构: $(uname -m)，请手动指定 amd64/arm64/armv7"
    log "自动检测架构: ${BOLD}$arch${NC} ($(uname -m))"
  fi
  prepare_basics
  prepare_dirs
  download_pkg "$arch"
  init_account
  stop_services
  start_services
  print_banner "$arch"
}

do_uninstall() {
  echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║   ⚠️   卸载 EPG 系统 (恢复原始状态)         ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
  echo -e "  将执行:"
  echo -e "    1) 停止后端进程"
  echo -e "    2) 移除 nginx EPG 站点配置 (保留 nginx 本身)"
  echo -e "    3) 删除 ${INSTALL_DIR}"
  echo -e "    4) 删除 ${EPG_DIR} (含数据库 + htpasswd)"
  echo
  read -r -p "确认输入 ${RED}YES${NC} 继续: " ans
  if [ "$ans" != "YES" ]; then
    warn "已取消"
    return
  fi
  stop_services
  remove_nginx_site
  $SUDO rm -rf "$INSTALL_DIR" "$EPG_DIR"
  log "✅ 已卸载并恢复原始状态"
}

do_update() {
  log "更新 = 重新下载二进制 + 同步 nginx 配置 + 重启"
  local arch; arch="$(detect_arch)"
  download_pkg "$arch"
  # 重新写 nginx 配置（v0.0.3 起去掉 auth_basic 改用前端登录页）
  setup_nginx || true
  stop_services
  start_services
  print_banner "$arch"
}

do_status() {
  echo "============================================"
  echo "  EPG 服务状态"
  echo "============================================"
  if pgrep -af "$INSTALL_DIR/epg-server" >/dev/null 2>&1; then
    pgrep -af "$INSTALL_DIR/epg-server" | sed 's/^/  后端: /'
  else
    echo -e "  后端 : ${RED}未运行${NC}"
  fi
  if pgrep -x nginx >/dev/null 2>&1; then
    echo -e "  nginx: ${GREEN}运行中${NC} ($(pgrep -x nginx | tr '\n' ' '))"
  else
    echo -e "  nginx: ${RED}未运行${NC}"
  fi
  echo "  配置 : $(nginx_conf_target)"
  echo "  端口 : 前端 $FRONTEND_PORT / 后端 $BACKEND_PORT"
  echo "  数据 : $EPG_DIR"
  echo "  安装 : $INSTALL_DIR"
  echo "============================================"
}

do_logs() {
  echo "[Ctrl+C 退出查看]"
  tail -f "$INSTALL_DIR/logs/server.log" 2>/dev/null \
    || warn "未找到日志文件: $INSTALL_DIR/logs/server.log"
}

# ---------------- 菜单 ----------------
show_menu() {
  clear 2>/dev/null || true
  local arch; arch="$(detect_arch)"
  echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${NC}     ${BOLD}EPG 系统  一键远程安装/管理${NC}             ${BLUE}║${NC}"
  echo -e "${BLUE}║${NC}     ${CYAN}https://github.com/judy-gotv/Rust-EPG${NC}  ${BLUE}║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
  echo -e "  当前架构 : ${CYAN}${arch}${NC} ($(uname -m))"
  echo -e "  安装目录 : ${CYAN}${INSTALL_DIR}${NC}"
  echo -e "  数据目录 : ${CYAN}${EPG_DIR}${NC}"
  echo -e "  端  口   : 后端 ${CYAN}${BACKEND_PORT}${NC} / 前端 ${CYAN}${FRONTEND_PORT}${NC}"
  echo -e "${BLUE}--------------------------------------------${NC}"
  echo -e "  ${GREEN}1)${NC}  一键安装 (自动识别架构)        ${YELLOW}★ 推荐${NC}"
  echo -e "  ${GREEN}2)${NC}  指定架构安装 (amd64 / arm64 / armv7)"
  echo -e "  ${GREEN}3)${NC}  更新到最新版 (重新下载二进制)"
  echo -e "  ${GREEN}4)${NC}  启动服务"
  echo -e "  ${GREEN}5)${NC}  停止服务"
  echo -e "  ${GREEN}6)${NC}  查看运行状态"
  echo -e "  ${GREEN}7)${NC}  查看实时日志"
  echo -e "  ${RED}8)${NC}  卸载 (恢复原始状态)"
  echo -e "  ${YELLOW}0)${NC}  退出"
  echo -e "${BLUE}============================================${NC}"
}

menu_loop() {
  while true; do
    show_menu
    read -r -p "请选择 [0-8]: " choice
    case "$choice" in
      1) do_install auto;  read -r -p "按回车返回菜单..." _ ;;
      2)
         echo "  a) amd64    b) arm64    c) armv7"
         read -r -p "选择 [a/b/c]: " a
         case "$a" in
           a|A|amd64) do_install amd64 ;;
           b|B|arm64) do_install arm64 ;;
           c|C|armv7) do_install armv7 ;;
           *) warn "无效选择" ;;
         esac
         read -r -p "按回车返回菜单..." _ ;;
      3) do_update;     read -r -p "按回车返回菜单..." _ ;;
      4) start_services; print_banner "$(detect_arch)"; read -r -p "按回车返回菜单..." _ ;;
      5) stop_services; log "✅ 已停止"; read -r -p "按回车返回菜单..." _ ;;
      6) do_status;     read -r -p "按回车返回菜单..." _ ;;
      7) do_logs ;;
      8) do_uninstall;  read -r -p "按回车返回菜单..." _ ;;
      0) echo "Bye 👋"; exit 0 ;;
      *) warn "无效选择: $choice"; sleep 1 ;;
    esac
  done
}

# ---------------- 入口 ----------------
case "${1:-}" in
  install)            do_install "${2:-auto}" ;;
  install-amd64)      do_install amd64 ;;
  install-arm64)      do_install arm64 ;;
  install-armv7)      do_install armv7 ;;
  update)             do_update ;;
  start)              start_services; print_banner "$(detect_arch)" ;;
  stop)               stop_services; log "✅ 已停止" ;;
  status)             do_status ;;
  logs)               do_logs ;;
  uninstall|remove)   do_uninstall ;;
  menu|"")            menu_loop ;;
  -h|--help|help)
    cat <<EOF
EPG 系统一键安装脚本

用法:
  bash $0                  # 交互菜单 (默认)
  bash $0 install [arch]   # 安装 (arch: auto|amd64|arm64|armv7)
  bash $0 update           # 更新到最新版
  bash $0 start|stop       # 启停服务
  bash $0 status           # 查看状态
  bash $0 logs             # 实时日志
  bash $0 uninstall        # 卸载

环境变量:
  EPG_DIR=/opt/epg
  INSTALL_DIR=/opt/epg/app
  BACKEND_PORT=8080
  FRONTEND_PORT=8081
  EPG_DEFAULT_USER=admin
  EPG_DEFAULT_PASS=admin123
EOF
    ;;
  *) error "未知命令: $1   (使用 'bash $0 help' 查看帮助)" ;;
esac
