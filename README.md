# EPG 系统 (Rust + SQLite + Redis)

一个高性能的 EPG (Electronic Program Guide / 电子节目单) 系统，提供多源数据采集、聚合、查询和导出。

后端使用 **Rust + Axum + SQLite + Redis**，前端使用 **Vue 3 + Vite + Element Plus**，开箱即用，一行命令即可在 Linux 服务器部署。

---

## 🌐 在线演示

| 入口 | 链接 |
|---|---|
| 🏠 首页 (频道+节目+在线解析) | https://epg.passwd.bond |
| 🔐 后台管理 | https://epg.passwd.bond/admin |
| 📡 XMLTV 订阅 | https://epg.passwd.bond/epg.xml.gz |
| 📺 DIYP 订阅 | https://epg.passwd.bond/diyp |

---

## ✨ 特性

- 🚀 **高性能** — Rust 后端 + SQLite (bundled) + Redis 缓存
- 🌐 **多架构** — 预编译 `linux/amd64` `linux/arm64` `linux/arm/v7` 三个架构的二进制
- 📦 **零依赖部署** — 静态链接 + rustls (无需 OpenSSL)，glibc 2.17 兼容 (CentOS 7+/Ubuntu 18.04+)
- 🔌 **多源采集** — 支持 XMLTV / JSON / CSV 数据源，定时同步
- 🔗 **在线解析外部 EPG** — 首页直接输入任意 XMLTV URL 即可加载预览（无需入库）
- 🔐 **HTTP Basic 鉴权** — 后台管理由 nginx 拦截，bcrypt 加密
- 🛡️ **后端默认绑 127.0.0.1** — 必须经由 nginx 反代，杜绝裸奔
- 🎨 **现代化 UI** — Vue 3 + Element Plus 响应式界面
- 📊 **Prometheus 指标** — 内置 `/metrics` 监控端点
- 📤 **IPTV 订阅地址** — XMLTV / DIYP 多种格式，开箱即用
- ⏰ **定时任务** — cron 表达式调度采集与清理
- 🐳 **Docker 支持** — 同时提供 docker-compose 方式

---

## 🚀 快速开始 (推荐 - 一键远程安装)

> 💡 **已经装了宝塔面板？** 直接跳到 [🪟 宝塔面板专用教程](#-宝塔面板-bt-panel-专用教程)。

### 一行命令安装

```bash
curl -fsSL https://raw.githubusercontent.com/judy-gotv/Rust-EPG/main/install.sh | bash -s install

或者

curl -fsSL https://github.com/judy-gotv/Rust-EPG/releases/latest/download/install.sh | bash -s install
```

或先下载脚本进入交互菜单：

```bash
curl -fsSL https://raw.githubusercontent.com/judy-gotv/Rust-EPG/main/install.sh -o install.sh
bash install.sh
或者
curl -fsSL https://github.com/judy-gotv/Rust-EPG/releases/latest/download/install.sh
bash install.sh
```

### 一行命令升级
```bash
curl -fsSL https://github.com/judy-gotv/Rust-EPG/releases/latest/download/install.sh | bash -s update
```

### 安装脚本会自动完成

1. ✅ 检测 CPU 架构 (`amd64` / `arm64` / `armv7`)
2. ✅ 安装系统依赖 (`curl`, `tar`, `htpasswd`, `nginx`)
3. ✅ 创建 `/opt/epg` 数据目录
4. ✅ 从 GitHub 下载对应架构的二进制包
5. ✅ 创建默认账号 `admin / admin123`
6. ✅ 配置 nginx 反向代理（**仅占用 8081 端口，不抢 80/443**）
7. ✅ 启动后端服务

### 访问

```
前端首页 : http://<服务器IP>:8081
后台管理 : http://<服务器IP>:8081/admin    👈 登录入口

默认账号 : admin
默认密码 : admin123
```

> ⚠️ **首次登录后请立即在后台修改密码！**

---

## 🎛 交互菜单

```
╔════════════════════════════════════════════╗
║     EPG 系统  一键远程安装/管理              ║
║     https://github.com/judy-gotv/Rust-EPG  ║
╚════════════════════════════════════════════╝
  1)  一键安装 (自动识别架构)        ★ 推荐
  2)  指定架构安装 (amd64 / arm64 / armv7)
  3)  更新到最新版 (重新下载二进制)
  4)  启动服务
  5)  停止服务
  6)  查看运行状态
  7)  查看实时日志
  8)  卸载 (恢复原始状态)
  0)  退出
============================================
```

### 命令行模式

```bash
bash install.sh install         # 一键安装
bash install.sh install amd64   # 指定架构
bash install.sh update          # 升级到最新版（保留数据）
bash install.sh start           # 启动
bash install.sh stop            # 停止
bash install.sh status          # 查看状态
bash install.sh logs            # 实时日志
bash install.sh uninstall       # 卸载（恢复原始状态）
bash install.sh help            # 帮助
```

---

## 📁 安装目录结构

```
/opt/epg/                              ← 数据 + 配置总目录
├── app/                               ← 程序本体
│   ├── epg-server                     ← 后端二进制
│   ├── web/                           ← 前端静态资源
│   ├── config.yml                     ← 后端配置
│   ├── migrations/                    ← SQLite 迁移
│   ├── run.sh                         ← 服务管理脚本
│   └── logs/
│       ├── server.log
│       └── server.pid
├── data/
│   └── epg.db                         ← SQLite 数据库
├── conf/
├── epg.htpasswd                       ← 登录账号文件 (admin/admin123)
└── nginx-domain-example.conf          ← 域名 + HTTPS 反代示例
```

升级时只覆盖 `app/`，**数据库和账号永远不丢**。

---

## 📦 预编译二进制

| 架构 | 下载 | 适用 |
|---|---|---|
| `linux/amd64` | [epg-linux-amd64.tar.gz](https://github.com/judy-gotv/Rust-EPG/raw/main/epg-linux-amd64.tar.gz) | 普通 x86_64 服务器（绝大多数 VPS） |
| `linux/arm64` | [epg-linux-arm64.tar.gz](https://github.com/judy-gotv/Rust-EPG/raw/main/epg-linux-arm64.tar.gz) | 树莓派 4/5、AWS Graviton、鲲鹏、Apple Silicon |
| `linux/arm/v7` | [epg-linux-armv7.tar.gz](https://github.com/judy-gotv/Rust-EPG/raw/main/epg-linux-armv7.tar.gz) | 树莓派 2/3、老款路由器/盒子 |

不知道架构？运行 `uname -m`：
- `x86_64` → amd64
- `aarch64` → arm64
- `armv7l` / `armhf` → armv7

每个包都是**完整版**，含后端二进制 + 前端 dist + 配置 + 迁移 + 启动脚本。

---

## 🌐 配置域名 + HTTPS

EPG 默认使用端口 `8081`，**不占用 80/443**。挂域名 + HTTPS：

```bash
# 1. 复制内置示例配置
cp /opt/epg/nginx-domain-example.conf /etc/nginx/conf.d/epg-domain.conf

# 2. 替换为你的域名
sed -i 's/epg.example.com/你的域名.com/g' /etc/nginx/conf.d/epg-domain.conf

# 3. 用 certbot 一键申请 HTTPS 证书
apt install -y certbot python3-certbot-nginx     # Debian/Ubuntu
# 或 yum install -y certbot python3-certbot-nginx   # CentOS

certbot --nginx -d 你的域名.com

# 4. 重载
nginx -t && nginx -s reload
```

之后访问 `https://你的域名.com/admin` 即可。

---

## 🪟 宝塔面板 (BT Panel) 专用教程

如果你的服务器已经安装了**宝塔面板**，`install.sh` 会和宝塔的 nginx 冲突（宝塔 nginx 装在 `/www/server/nginx/`，配置目录是 `/www/server/panel/vhost/nginx/`，**不读** `/etc/nginx/conf.d/`）。请按下面流程手动接入：

### Step 1️⃣ 先用 install.sh 安装"后端 + 文件"

只跑后端二进制部署，不让脚本碰 nginx：

```bash
curl -fsSL https://github.com/judy-gotv/Rust-EPG/releases/latest/download/install.sh | bash -s install
```

脚本会执行：
- ✅ 检测 CPU 架构、下载二进制
- ✅ 创建 `/opt/epg`、初始化 admin/admin123
- ✅ 启动后端（监听 `127.0.0.1:8080`）
- ⚠️ 写了一份 `/etc/nginx/conf.d/epg.conf`（**宝塔 nginx 不会读，可以忽略或删掉**）

验证后端通了：
```bash
curl http://127.0.0.1:8080/health
# 期望: {"status":"ok"}
```

### Step 2️⃣ 宝塔面板 → 添加站点

| 字段 | 填什么 |
|---|---|
| 域名 | `epg.yourdomain.com`（你的域名） |
| 备注 | 随便 |
| **根目录** | `/opt/epg/app/web` ⚠️ **必须这个，不要让宝塔追加域名后缀** |
| FTP | 不创建 |
| 数据库 | 不创建 |
| PHP 版本 | 纯静态 |

点确定。

### Step 3️⃣ 编辑站点配置文件

进入站点 → 左侧菜单 **配置文件** → 找到 `server { ... }` 块，在 `root /opt/epg/app/web;` **下面**粘贴：

```nginx
# ===== EPG 配置开始 =====

# 管理 API - Basic Auth 拦截（必须放在 /api/ 前面）
location /api/v1/admin {
    auth_basic           "EPG Admin";
    auth_basic_user_file /opt/epg/epg.htpasswd;

    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Authorization $http_authorization;
    proxy_read_timeout 300s;
}

# 公开 API
location /api/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 300s;
}

# 健康检查 / Prometheus
location ~ ^/(health|metrics)$ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
}

# EPG 订阅地址 (XMLTV / DIYP)
location ~ ^/(epg\.xml|epg\.xml\.gz|e\.xml|e\.xml\.gz|diyp|epg/diyp)$ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_read_timeout 300s;
}

# 前端 SPA - 必须放最后（兜底）
location / {
    try_files $uri $uri/ /index.html;
}

# ===== EPG 配置结束 =====
```

⚠️ **如果你看到 `#PROXY-START/ ... #PROXY-END/` 段落**（宝塔反向代理生成的），整段**删掉**，避免把全站都代理到 8080。

按 **Ctrl + S** 保存，宝塔会自动 `nginx -t` 校验，绿色提示就 OK。

### Step 4️⃣ 申请 SSL 证书

站点设置 → 左侧 **SSL** → Let's Encrypt → 勾选域名 → 申请 → 申请成功后开启 **强制 HTTPS**。

### Step 5️⃣ 验证

```bash
# 前端首页应该返回 HTML
curl -I https://epg.yourdomain.com/

# 公开 API 应该返回 200
curl -I https://epg.yourdomain.com/api/v1/channels

# 管理 API 不带密码应该返回 401（重点：证明 auth_basic 生效）
curl -I https://epg.yourdomain.com/api/v1/admin/sources
# HTTP/1.1 401 Unauthorized ✅

# XMLTV 订阅应该返回 XML
curl -I https://epg.yourdomain.com/epg.xml.gz
# Content-Type: application/gzip ✅
```

浏览器访问 `https://epg.yourdomain.com/admin` → 弹登录框 → `admin / admin123` ✅

### Step 6️⃣ （可选）让 install.sh 不再插嘴

宝塔模式下不需要 install.sh 自动改 nginx，可以让它"只装后端不动 nginx"：

```bash
# 升级时只下二进制 + 重启后端，不碰 nginx 配置
bash install.sh update
```

`update` 命令只覆盖二进制，不重写 nginx 站点，宝塔配置永远不丢。

### ⚠️ 宝塔用户常见坑

| 坑 | 解决 |
|---|---|
| 浏览器打开域名是宝塔默认页 | 站点没绑对域名 / 没解析到本机 IP |
| `https://你的域名/admin` 返回 JSON 而不是 HTML | 反代顺序写反了，`location /` 写到 `/api/` 前面会被截胡。**确保 `location /` 在最后** |
| `/api/v1/admin` 直接进去不要密码 | `auth_basic_user_file` 路径写错或文件不存在，检查 `ls -la /opt/epg/epg.htpasswd` |
| `502 Bad Gateway` | 后端没启动。`curl http://127.0.0.1:8080/health` 测试，并查 `tail /opt/epg/app/logs/server.log` |
| 改完密码网页没掉线 | 浏览器缓存了 Basic Auth 凭证，关浏览器重开或用隐身窗口 |
| 域名首页 404 | 网站目录写成了 `/opt/epg/app/web/epg.yourdomain.com`（多了一层）。删站点重建，根目录就填 `/opt/epg/app/web` |

---

## ⚙️ 自定义配置

通过环境变量自定义安装路径和端口：

```bash
EPG_DIR=/www/epg \
INSTALL_DIR=/www/epg/app \
BACKEND_PORT=9090 \
FRONTEND_PORT=9091 \
EPG_DEFAULT_USER=myuser \
EPG_DEFAULT_PASS=MyStrongPass123 \
bash install.sh install
```

| 变量 | 默认 | 说明 |
|---|---|---|
| `EPG_DIR` | `/opt/epg` | 数据/配置目录 |
| `INSTALL_DIR` | `/opt/epg/app` | 程序安装目录 |
| `BACKEND_PORT` | `8080` | 后端端口（仅监听 127.0.0.1） |
| `FRONTEND_PORT` | `8081` | nginx 站点端口（对外） |
| `EPG_DEFAULT_USER` | `admin` | 默认用户名 |
| `EPG_DEFAULT_PASS` | `admin123` | 默认密码 |
| `EPG_HTPASSWD_PATH` | `$EPG_DIR/epg.htpasswd` | htpasswd 文件路径 |

---

## 🛠 从源码编译

### 依赖

- Rust 1.75+（推荐 stable）
- Node.js 20+
- (可选) Docker，用于交叉编译

### 后端

```bash
cd epg-server
cargo build --release
./target/release/epg-server
```

### 前端

```bash
cd epg-web
npm install
npm run build      # 产出 dist/
npm run dev        # 本地开发
```

### 交叉编译三个架构

需先安装 [zig](https://ziglang.org/) 作为 C 编译器，配置 `.cargo/config.toml`（仓库已包含示例）：

```bash
rustup target add x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu armv7-unknown-linux-gnueabihf
cd epg-server
cargo build --release --target x86_64-unknown-linux-gnu
cargo build --release --target aarch64-unknown-linux-gnu
cargo build --release --target armv7-unknown-linux-gnueabihf
```

---

## 🐳 Docker 部署

```bash
git clone https://github.com/judy-gotv/Rust-EPG.git
cd Rust-EPG/deploy
docker compose up -d --build
```

```yaml
# 默认暴露
epg-redis  : 6379
epg-server : 8080
epg-web    : 8081
```

---

## 📡 API 文档

### 公开 API (无需鉴权)

| 路径 | 方法 | 说明 |
|---|---|---|
| `/health` | GET | 健康检查 |
| `/metrics` | GET | Prometheus 指标 |
| `/api/v1/channels?page=1&page_size=1000` | GET | 频道列表（page_size 最大 5000） |
| `/api/v1/channels/:code` | GET | 频道详情 |
| `/api/v1/categories` | GET | 分类列表 |
| `/api/v1/programs?channel_code=xxx&start=...&end=...` | GET | 节目列表 |
| `/api/v1/programs/current?channel_code=xxx` | GET | 正在播放 |
| `/api/v1/programs/next?channel_code=xxx` | GET | 下一个节目 |
| `/api/v1/search?q=xxx` | GET | 全文检索 |
| `/api/v1/parse-url` | POST | **解析任意外部 XMLTV URL** (body: `{"url":"..."}`，不入库) |
| `/api/v1/theme` | GET | 获取当前主题 |

### IPTV 订阅地址 (无需鉴权)

| 路径 | 用途 |
|---|---|
| `/epg.xml` | XMLTV (Kodi / Jellyfin / IPTV Smarters / m3u 通用) |
| `/epg.xml.gz` | XMLTV gzip 压缩版 ⭐ 推荐 |
| `/e.xml` `/e.xml.gz` | 上面的别名 |
| `/diyp` 或 `/epg/diyp` | DIYP / TVBox / 影视仓 JSON 格式 |

可选参数：
```
?days=7              # 天数（默认 7，最大 30）
?channels=cctv1,cctv2 # 只导出指定频道（逗号分隔）
```

### 管理 API (需 Basic Auth - 由 nginx 拦截)

| 路径 | 方法 | 说明 |
|---|---|---|
| `/api/v1/admin/sources` | GET/POST | 数据源管理 |
| `/api/v1/admin/sources/:id` | PUT/DELETE | 修改/删除数据源 |
| `/api/v1/admin/sources/:id/sync` | POST | 手动触发同步 |
| `/api/v1/admin/channels` | POST | 创建频道 |
| `/api/v1/admin/channels/:id` | DELETE | 删除频道 |
| `/api/v1/admin/sync/logs` | GET | 同步日志 |
| `/api/v1/admin/mappings/channel` | GET/POST | 频道映射 |
| `/api/v1/admin/mappings/field` | GET/POST | 字段映射 |
| `/api/v1/admin/change-password` | POST | 修改密码 |
| `/api/v1/admin/theme` | POST | 设置主题 |

---

## ⚙️ 配置文件

`config.yml` 默认值：

```yaml
server:
  host: "0.0.0.0"
  port: 8080

database:
  path: "./data/epg.db"
  pool_size: 10

redis:
  url: "redis://127.0.0.1:6379/0"
  cache_ttl_secs: 300

log:
  level: "info"

collector:
  default_timezone: "Asia/Shanghai"
  http_timeout_secs: 30

scheduler:
  sync_cron: "0 0 */6 * * *"     # 每 6 小时同步
  cleanup_cron: "0 0 3 * * *"    # 每天 3 点清理
```

---

## 🧰 技术栈

### 后端
- **Web 框架**: [axum](https://github.com/tokio-rs/axum) 0.7
- **运行时**: [tokio](https://tokio.rs/)
- **数据库**: [rusqlite](https://github.com/rusqlite/rusqlite) (bundled)
- **缓存**: [redis-rs](https://github.com/redis-rs/redis-rs)
- **HTTP 客户端**: [reqwest](https://github.com/seanmonstar/reqwest) (rustls)
- **XML**: [quick-xml](https://github.com/tafia/quick-xml)
- **调度**: [tokio-cron-scheduler](https://github.com/mvniekerk/tokio-cron-scheduler)
- **监控**: [prometheus](https://github.com/tikv/rust-prometheus)

### 前端
- [Vue 3](https://vuejs.org/) + [Vite](https://vitejs.dev/)
- [Element Plus](https://element-plus.org/)
- [Vue Router](https://router.vuejs.org/)
- [Axios](https://axios-http.com/)

---

## 🧹 卸载

```bash
bash install.sh uninstall
# 输入 YES 确认
```

会执行：
1. 停止后端进程
2. 移除 nginx EPG 站点配置（保留 nginx 本身）
3. 删除 `/opt/epg/app/`
4. 删除 `/opt/epg/`（含数据库 + htpasswd）

完全恢复到安装前状态。

---

## ❓ 常见问题

### Q: 安装报错 "无法识别架构"
A: 你的 CPU 架构不在三个预编译列表里，请[从源码编译](#-从源码编译)。

### Q: 后台登录失败
A:
1. 检查 `/opt/epg/epg.htpasswd` 是否存在
2. 重置密码：`htpasswd -bcB /opt/epg/epg.htpasswd admin 新密码`
3. 查看后端日志：`tail -f /opt/epg/app/logs/server.log`

### Q: 端口冲突
A: 改 `FRONTEND_PORT` 环境变量重新安装：`FRONTEND_PORT=9999 bash install.sh install`

### Q: 升级后数据丢失
A: 不会。升级（菜单选项 3）只覆盖二进制，`/opt/epg/data/epg.db` 不动。

### Q: Redis 必须装吗？
A: 不必须，没装就关闭缓存，性能会差一点。装 Redis：`docker run -d --restart unless-stopped -p 127.0.0.1:6379:6379 redis:7-alpine`

### Q: 如何配置 HTTPS？
A: 见上面 [配置域名 + HTTPS](#-配置域名--https)。

### Q: 如何在线预览别人家的 EPG？
A: 首页 EPG地址 输入框默认填了本站的 `/epg.xml.gz`。把它替换成任意 `https://xxx.com/epg.xml.gz` → 点【加載數據】即可预览（仅前端展示，不入库）。

---

## 📝 Changelog

### v0.0.3 (latest)

- ✨ **新增** 首页支持解析任意外部 EPG URL（`POST /api/v1/parse-url`，下载 → 解压 gzip → 解析 XMLTV → 直接展示，不入库）
- ✨ **新增** EPG地址输入框默认填入当前域名的 `/epg.xml.gz`，开箱即用
- 🐛 **修复** 频道列表只显示 500 个的 bug（后端 page_size 上限从 500 提到 5000，前端改为自动分页）
- 🐛 **修复** 主页 URL 默认重定向到 `/channels` 的问题（现在停在 `/`）
- 🔒 **安全** 后端默认绑定 `127.0.0.1`，必须经由 nginx 反代（避免管理 API 裸奔）
- 🔒 **安全** nginx 配置加入 `auth_basic` 拦截 `/api/v1/admin/*`
- 🔧 **改进** axios 超时从 15s 提到 120s（解析大 EPG 包不再卡死）

### v0.0.1

- 🎉 首个发布版本
- 多源 EPG 采集（XMLTV / JSON / CSV）
- IPTV 订阅地址（XMLTV / DIYP）
- HTTP Basic 鉴权 + bcrypt
- 定时任务 + Prometheus 监控
- 三架构预编译二进制（amd64 / arm64 / armv7）

---

## 📜 License

MIT

---

## 🤝 贡献

欢迎 Issue 和 Pull Request！

- 仓库: https://github.com/judy-gotv/Rust-EPG
- Issues: https://github.com/judy-gotv/Rust-EPG/issues

---

<p align="center">
  Made with ❤️ using Rust
</p>
