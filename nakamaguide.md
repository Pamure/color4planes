# 🎮 Nakama Game Server — Production Setup Guide
### For mark2 (Ubuntu 24.04 · i3-7100U · 16GB RAM) · Cloudflare Tunnels · Docker

---

> **What this guide builds:** A fully production-hardened Nakama multiplayer
> game server on your existing Ubuntu laptop. Accessible worldwide via
> Cloudflare Tunnels with zero port-forwarding, TLS handled automatically,
> auto-restarts on crash, log rotation, automated backups, and a monitoring
> dashboard — all optimised for your specific hardware.

---

## 🧠 Read This First — What You're Actually Building

```
Your Flutter Game (Phone / Browser)
        │
        │ HTTPS / WSS (WebSocket Secure)
        ▼
┌─────────────────────────────────────┐
│  Cloudflare's Global CDN Network   │   ← TLS termination, DDoS protection,
│  (tunnels.cloudflare.com)          │     global anycast routing — FREE
└──────────────┬──────────────────────┘
               │ Encrypted tunnel (outbound from your server)
               ▼
┌─────────────────────────────────────────────────────────────────┐
│  mark2 (Your ASUS Laptop)                                       │
│                                                                  │
│  ┌────────────────┐    ┌────────────────┐    ┌───────────────┐ │
│  │  cloudflared   │───►│  Nakama        │───►│  PostgreSQL   │ │
│  │  (tunnel)      │    │  :7350 HTTP    │    │  :5432        │ │
│  │                │    │  :7351 gRPC    │    │               │ │
│  │                │    │  :7352 console │    │               │ │
│  └────────────────┘    └────────────────┘    └───────────────┘ │
│                                                                  │
│  All three services run as Docker containers.                   │
│  Docker Compose manages them as a single unit.                  │
│  Systemd auto-starts Docker Compose on boot.                    │
└─────────────────────────────────────────────────────────────────┘
```

**Why Cloudflare Tunnels instead of port-forwarding:**
- Your ISP might block inbound ports or change your IP
- No router config needed
- Free TLS certificate, automatically renewed
- DDoS protection included at the network level
- The tunnel is outbound-only — your laptop initiates it

**Why Docker Compose instead of bare metal Nakama:**
- One command (`docker compose up -d`) starts everything
- One command (`docker compose down`) stops cleanly
- Easy upgrades (change image version, run `docker compose pull && up`)
- PostgreSQL + Nakama configuration lives in plain files you can back up

---

## Hardware Reality Check — What This Machine Can Handle

Your i3-7100U + 16GB RAM is modest but capable. Real expectations:

| Scenario | Concurrent Players | Notes |
|----------|-------------------|-------|
| Development + testing | 1–10 | Fine with no tuning |
| Soft launch | 10–50 | Fine as-is |
| Small live game | 50–150 | Needs tuning (this guide does it) |
| Medium live game | 150–300 | Possible with aggressive tuning, i3 becomes the bottleneck |

The i3-7100U has 2 cores / 4 threads at 2.4GHz. Nakama is a Go server
(efficient, low overhead). PostgreSQL on SSD handles ~1000 queries/sec easily.
Your main limit is CPU for cryptography (JWT signing, WebSocket framing)
and RAM for connection state. At 16GB you're fine for 150+ players.

---

---

# PART 1 — System Preparation

## Step 1.1 — Apply Pending Updates

You had 4 pending updates and a restart required. Do that first.

```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

After reboot, SSH back in:
```bash
ssh yarmuk
```

---

## Step 1.2 — Install Required Tools

```bash
sudo apt install -y \
  curl \
  wget \
  git \
  htop \
  jq \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  fail2ban \
  ufw \
  logrotate
```

**What each tool does:**
- `curl` / `wget` — download files from the terminal
- `htop` — interactive process viewer (like Task Manager)
- `jq` — parse JSON from the terminal (useful for debugging Nakama API)
- `fail2ban` — automatically bans IPs that fail SSH login repeatedly
- `ufw` — Uncomplicated Firewall — simple rules for iptables
- `logrotate` — automatically compress and trim log files

---

## Step 1.3 — Verify Docker is Installed and Working

Docker is already running on your machine (you have docker0, multiple veth
interfaces, and Docker bridges visible in your network list). Verify:

```bash
docker --version
docker compose version
```

You should see something like:
```
Docker version 27.x.x, build ...
Docker Compose version v2.x.x
```

If `docker compose` (v2, no hyphen) fails, install the plugin:
```bash
sudo apt install -y docker-compose-plugin
```

Make sure your user is in the docker group (avoids needing `sudo` every time):
```bash
sudo usermod -aG docker $USER
newgrp docker  # Apply without logging out
```

Test it works:
```bash
docker run --rm hello-world
```

---

## Step 1.4 — Create the Project Directory Structure

Everything lives in one organised folder. This makes backups, upgrades,
and debugging straightforward.

```bash
sudo mkdir -p /opt/nakama/{data,postgres,config,backups,logs}
sudo chown -R $USER:$USER /opt/nakama
```

**What each subfolder is for:**
```
/opt/nakama/
├── data/           ← Nakama runtime data (Lua/JS modules if you add them later)
├── postgres/       ← PostgreSQL data files (persisted across container restarts)
├── config/         ← Nakama config file and secrets
├── backups/        ← Automated database backups go here
└── logs/           ← Separate log directory (log rotation targets this)
```

---

## Step 1.5 — Firewall Setup with UFW

You use Cloudflare Tunnels, so you don't need any inbound ports open
on your router or firewall. The tunnel initiates outbound.

However, UFW should still be on and tight — in case something tries to
reach your machine through your local network.

```bash
# Reset to a clean state
sudo ufw --force reset

# Default: deny everything inbound, allow everything outbound
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (CRITICAL — do this BEFORE enabling, or you'll lock yourself out)
sudo ufw allow ssh

# Allow traffic from your local network (192.168.1.x) — for Tailscale/local dev
sudo ufw allow from 192.168.1.0/24

# If you use Tailscale to SSH (the wt0 interface), allow that subnet
# Tailscale uses 100.64.0.0/10 by default
sudo ufw allow from 100.64.0.0/10

# Enable
sudo ufw enable
sudo ufw status verbose
```

**What you should see:**
```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
Anywhere                   ALLOW IN    192.168.1.0/24
Anywhere                   ALLOW IN    100.64.0.0/10
```

Nakama's ports (7350, 7351, 7352) are intentionally NOT open here.
All external traffic comes through the Cloudflare Tunnel (encrypted,
authenticated). Local access still works via your LAN or Tailscale.

---

## Step 1.6 — Harden SSH

```bash
sudo nano /etc/ssh/sshd_config
```

Find and set these values (add them if they don't exist):

```
# Disable root login — root should never SSH in directly
PermitRootLogin no

# Disable password authentication — key-only (you already use keys via Tailscale)
PasswordAuthentication no

# Only allow your user
AllowUsers gomango

# Connection timeout — disconnect idle sessions after 10 minutes
ClientAliveInterval 300
ClientAliveCountMax 2

# Limit auth attempts
MaxAuthTries 3

# Disable X11 forwarding (you're headless)
X11Forwarding no
```

Apply:
```bash
sudo systemctl restart sshd
```

**DO NOT close your current SSH session** until you've tested a new session
connects correctly. Open a second terminal tab and `ssh yarmuk` to verify.

---

## Step 1.7 — Configure fail2ban

fail2ban watches your SSH logs and bans IPs that fail login 3+ times.

```bash
sudo nano /etc/fail2ban/jail.local
```

Paste this:

```ini
[DEFAULT]
# Ban for 1 hour after 3 failed attempts within 10 minutes
bantime  = 3600
findtime = 600
maxretry = 3

# Never ban your local network or Tailscale
ignoreip = 127.0.0.1/8 ::1 192.168.1.0/24 100.64.0.0/10

[sshd]
enabled  = true
port     = ssh
logpath  = %(sshd_log)s
backend  = %(syslog_backend)s
```

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd  # Should show "Currently banned: 0"
```

---

---

# PART 2 — Docker Compose Stack

## Step 2.1 — Create the Environment File (Secrets)

Secrets never go directly in `docker-compose.yml`. They live in `.env`.
This file never gets committed to Git.

```bash
nano /opt/nakama/.env
```

Paste and fill in YOUR values:

```bash
# ── PostgreSQL ────────────────────────────────────────────────────────────────
# Change these — use a strong password (30+ random characters)
POSTGRES_USER=nakama
POSTGRES_PASSWORD=CHANGE_THIS_TO_A_STRONG_RANDOM_PASSWORD_HERE
POSTGRES_DB=nakama

# ── Nakama ────────────────────────────────────────────────────────────────────
# Server key — clients must present this to connect. Make it unique and random.
NAKAMA_SERVER_KEY=colorplanes-server-key-CHANGE-THIS-TOO

# Console admin password — for the Nakama web dashboard
NAKAMA_CONSOLE_PASSWORD=CHANGE_THIS_CONSOLE_PASSWORD_ALSO

# ── Your domain (set this up in Part 3 — Cloudflare) ──────────────────────────
# This is the domain you'll expose via Cloudflare Tunnel
# Example: nakama.yourname.com  or  game.yourdomain.com
NAKAMA_DOMAIN=nakama.yourdomain.com
```

Secure the file — only your user can read it:
```bash
chmod 600 /opt/nakama/.env
```

**How to generate a strong random password:**
```bash
openssl rand -base64 32
```
Run it twice — once for the DB password, once for the server key.

---

## Step 2.2 — Create the Nakama Configuration File

Nakama reads a YAML config at startup. This controls every behaviour.

```bash
nano /opt/nakama/config/config.yml
```

```yaml
# /opt/nakama/config/config.yml
#
# Full Nakama configuration reference:
# https://heroiclabs.com/docs/nakama/getting-started/configuration/
#
# Values here are optimised for:
#   - i3-7100U (2 cores / 4 threads)
#   - 16GB RAM
#   - Small-medium game (Color4Planes)
#   - Cloudflare Tunnel frontend

name: colorplanes-nakama

# ── Database ──────────────────────────────────────────────────────────────────
database:
  addresses:
    # Points to the PostgreSQL container by its Docker Compose service name
    - "postgres:5432"

# ── API Server ────────────────────────────────────────────────────────────────
api:
  port: 7350
  # Only bind to localhost — Cloudflare Tunnel connects locally
  # NEVER bind to 0.0.0.0 in production if using a tunnel
  address: 127.0.0.1
  # Max message size in bytes (1MB is generous for a game)
  max_message_size_bytes: 1048576
  # Read timeout for HTTP (seconds)
  read_timeout_ms: 10000
  write_timeout_ms: 10000
  idle_timeout_ms: 60000

# ── gRPC API ──────────────────────────────────────────────────────────────────
# Flutter Nakama SDK can use either HTTP or gRPC. gRPC is faster.
grpc:
  port: 7351
  address: 127.0.0.1

# ── Console ───────────────────────────────────────────────────────────────────
console:
  port: 7352
  address: 127.0.0.1
  # max_message_size_bytes is lower for console (you don't need big uploads)
  max_message_size_bytes: 131072

# ── Socket (Real-time WebSocket) ──────────────────────────────────────────────
socket:
  port: 7350      # Same port as API — Nakama handles both
  address: 127.0.0.1
  # Ping period — server sends a ping to keep connections alive
  ping_period_ms: 15000
  ping_backoff_threshold: 20
  # Outgoing queue size per connection — increase if you see "queue full" errors
  outgoing_queue_size: 64
  max_request_size_bytes: 131072

# ── Runtime ───────────────────────────────────────────────────────────────────
runtime:
  # Where your server-side Lua or JS game logic lives (empty for now)
  path: "/nakama/data/modules"
  # Number of goroutines for runtime execution
  # Rule: (CPU cores × 2) — your i3 has 4 threads
  min_count: 4
  max_count: 16
  call_stack_size: 128
  max_message_size_bytes: 4194304

# ── Session (Auth Tokens) ──────────────────────────────────────────────────────
session:
  # How long a session token is valid (seconds) — 7 days
  token_expiry_sec: 604800
  # How long before the token expires to allow refresh (1 day)
  refresh_token_expiry_sec: 86400

# ── Logger ────────────────────────────────────────────────────────────────────
logger:
  # "info" for production, "debug" for development
  level: "info"
  # Log to stdout — Docker captures this and docker compose logs shows it
  stdout: true
  # Also write to a file
  file: "/nakama/logs/nakama.log"

# ── Matchmaker ────────────────────────────────────────────────────────────────
matchmaker:
  # How often Nakama tries to form matches from the queue (milliseconds)
  interval_sec: 5
  max_tickets: 500

# ── Leaderboard ───────────────────────────────────────────────────────────────
leaderboard:
  # How often scores are cached in-memory (seconds)
  callback_queue_size: 10
  join_queue_size: 10

# ── Metrics ───────────────────────────────────────────────────────────────────
metrics:
  # Expose Prometheus-compatible metrics at /metrics
  # Useful later if you add Grafana monitoring
  prometheus_port: 9100
  prefix: "colorplanes"
  reporting_freq_sec: 60
```

---

## Step 2.3 — Create docker-compose.yml

```bash
nano /opt/nakama/docker-compose.yml
```

```yaml
# /opt/nakama/docker-compose.yml
#
# Three services:
#   postgres  — the database (data persists in /opt/nakama/postgres/)
#   nakama    — the game server (depends on postgres being healthy)
#   migrate   — one-time DB schema setup (runs then exits)
#
# Start everything:    docker compose up -d
# Stop everything:     docker compose down
# See logs:            docker compose logs -f
# Upgrade Nakama:      docker compose pull && docker compose up -d

name: nakama-stack

services:

  # ── PostgreSQL ─────────────────────────────────────────────────────────────
  postgres:
    image: postgres:16-alpine
    # alpine = smaller image, faster pull, same functionality
    container_name: nakama_postgres
    restart: unless-stopped
    # unless-stopped means: restart automatically on crash or reboot,
    # but NOT if you manually ran `docker compose down`
    environment:
      POSTGRES_USER:     ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB:       ${POSTGRES_DB}
    volumes:
      # Mount the host directory into the container
      # This means your data SURVIVES container removal and upgrades
      - /opt/nakama/postgres:/var/lib/postgresql/data
    # Internal port — NOT exposed to the host network
    # Only containers in this Compose network can reach postgres:5432
    expose:
      - "5432"
    networks:
      - nakama-net
    # Resource limits — prevents PostgreSQL from eating all your RAM
    deploy:
      resources:
        limits:
          memory: 2G    # Max 2GB RAM for PostgreSQL
          cpus: '1.0'   # Max 1 CPU core
    healthcheck:
      # Docker will wait for postgres to be healthy before starting Nakama
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "3"

  # ── Nakama DB Migration ────────────────────────────────────────────────────
  # This service runs once to set up the database schema, then exits.
  # Nakama won't start with a blank database — migration creates the tables.
  migrate:
    image: heroiclabs/nakama:3.22.0
    container_name: nakama_migrate
    entrypoint:
      - "/bin/sh"
      - "-ecx"
      - >
        /nakama/nakama migrate up
        --database.address postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    volumes:
      - /opt/nakama/data:/nakama/data
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - nakama-net
    restart: on-failure

  # ── Nakama Server ──────────────────────────────────────────────────────────
  nakama:
    image: heroiclabs/nakama:3.22.0
    container_name: nakama_server
    restart: unless-stopped
    entrypoint:
      - "/bin/sh"
      - "-ecx"
      - >
        /nakama/nakama
        --config /nakama/config/config.yml
        --database.address postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
        --session.token_key ${NAKAMA_SERVER_KEY}
        --console.password ${NAKAMA_CONSOLE_PASSWORD}
    volumes:
      - /opt/nakama/config:/nakama/config:ro   # ro = read-only (config can't be modified by the process)
      - /opt/nakama/data:/nakama/data
      - /opt/nakama/logs:/nakama/logs
    ports:
      # IMPORTANT: Bind to 127.0.0.1 ONLY
      # 127.0.0.1:7350 → container:7350 means only localhost can reach this
      # Cloudflare Tunnel connects to 127.0.0.1:7350 from within the machine
      # External traffic NEVER hits these ports directly
      - "127.0.0.1:7350:7350"   # HTTP API + WebSocket
      - "127.0.0.1:7351:7351"   # gRPC
      - "127.0.0.1:7352:7352"   # Console dashboard
    depends_on:
      postgres:
        condition: service_healthy
      migrate:
        condition: service_completed_successfully
    networks:
      - nakama-net
    deploy:
      resources:
        limits:
          memory: 4G    # Max 4GB RAM for Nakama
          cpus: '2.5'   # Max 2.5 CPU cores (leaves 0.5 for OS + cloudflared)
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7350/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"

# ── Network ────────────────────────────────────────────────────────────────────
# Isolated bridge network — containers can talk to each other by service name
# but are NOT exposed to the host network unless explicitly port-mapped
networks:
  nakama-net:
    driver: bridge
    name: nakama-net
```

---

## Step 2.4 — First Launch

```bash
cd /opt/nakama

# Pull all images first (saves time on first start)
docker compose pull

# Start in detached mode (runs in background)
docker compose up -d

# Watch the logs — wait until you see "Nakama is ready"
docker compose logs -f
```

**What you should see in the logs:**
```
nakama_migrate  | {"level":"info","msg":"Database migration complete"}
nakama_migrate exited with code 0
nakama_server   | {"level":"info","msg":"Startup done"}
nakama_server   | {"level":"info","msg":"HTTP API server started listening","port":7350}
nakama_server   | {"level":"info","msg":"gRPC server started listening","port":7351}
```

**Test it works locally:**
```bash
curl http://localhost:7350/healthcheck
# Should return: {}
```

**Access the console dashboard (from your local network):**
```
http://192.168.1.8:7352
```

Wait — port 7352 is bound to `127.0.0.1` not the network IP. For local
network access you need to either use SSH port-forward or Tailscale:

```bash
# From YOUR development machine (not the server):
ssh -L 7352:localhost:7352 yarmuk
# Then open http://localhost:7352 in your browser
```

Login: `admin` / `[your NAKAMA_CONSOLE_PASSWORD from .env]`

---

## Step 2.5 — Systemd Auto-Start on Boot

Docker Desktop auto-starts on desktop machines, but on a server you want
Docker Compose to be managed by systemd — the init system that runs everything
on Ubuntu. This means it starts on boot, restarts on crash, and is manageable
with `systemctl`.

```bash
sudo nano /etc/systemd/system/nakama-stack.service
```

```ini
[Unit]
Description=Nakama Game Server Stack
Documentation=https://heroiclabs.com/docs/nakama/
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/nakama

# Environment file — loads .env variables into the service
EnvironmentFile=/opt/nakama/.env

ExecStart=/usr/bin/docker compose up -d --remove-orphans
ExecStop=/usr/bin/docker compose down
ExecReload=/usr/bin/docker compose up -d --remove-orphans

# Security hardening for the systemd unit
User=gomango
Group=gomango

# Restart on failure with a delay
Restart=on-failure
RestartSec=30s

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nakama-stack.service
sudo systemctl start nakama-stack.service
sudo systemctl status nakama-stack.service
```

**Test auto-start works:**
```bash
sudo reboot
# Wait ~60 seconds then SSH back in
ssh yarmuk
docker compose -f /opt/nakama/docker-compose.yml ps
# All services should show "running"
```
# PART 3 — Cloudflare Tunnel Setup

## Understanding What Cloudflare Tunnels Does Here

Normal server: your router has port 443 forwarded → server → app. Requires a
static IP or dynamic DNS, exposes your home network.

Cloudflare Tunnel: your `cloudflared` process on the server dials OUT to
Cloudflare's network and creates a persistent encrypted tunnel. Cloudflare
receives traffic on your domain and forwards it through that tunnel to your
local app. Your home network never has an inbound port open.

You already have `cloudflared-linux-amd64.deb` downloaded. Let's use it.

---

## Step 3.1 — Install cloudflared

You already downloaded the .deb — let's install it properly:

```bash
# Install the downloaded package
sudo dpkg -i ~/cloudflared-linux-amd64.deb

# Verify
cloudflared --version
```

---

## Step 3.2 — Authenticate with Your Cloudflare Account

```bash
cloudflared tunnel login
```

This opens a browser URL. Copy it into a browser on any machine logged into
your Cloudflare account, then authorize it. When done, a credentials file is
created at `~/.cloudflared/cert.pem`.

---

## Step 3.3 — Create the Tunnel

```bash
# Create a named tunnel (call it whatever you like)
cloudflared tunnel create nakama-colorplanes

# You'll see output like:
# Created tunnel nakama-colorplanes with id abc123-def456-...
# Tunnel credentials written to /home/gomango/.cloudflared/abc123-def456-....json

# Save the tunnel ID — you'll need it in the config
cloudflared tunnel list
```

---

## Step 3.4 — Create DNS Records

Point your domain's subdomain to this tunnel.
Replace `abc123-def456` with your actual tunnel ID.

```bash
# This creates a CNAME pointing nakama.yourdomain.com → tunnel
cloudflared tunnel route dns nakama-colorplanes nakama.yourdomain.com
```

Do the same for the console (only accessible from your tunnel — you'll
restrict it to be IP-limited later):

```bash
cloudflared tunnel route dns nakama-colorplanes nakama-console.yourdomain.com
```

---

## Step 3.5 — Create the Tunnel Configuration File

```bash
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

```yaml
# /etc/cloudflared/config.yml
#
# This tells cloudflared:
#   1. Which tunnel to use
#   2. What traffic to route where
#
# Replace YOUR_TUNNEL_ID with the actual ID from Step 3.3
# Replace yourdomain.com with your actual domain

tunnel: YOUR_TUNNEL_ID_HERE
credentials-file: /home/gomango/.cloudflared/YOUR_TUNNEL_ID_HERE.json

# Log level: "info" for production
loglevel: info
logfile: /var/log/cloudflared.log

ingress:
  # ── Game API + WebSocket ───────────────────────────────────────────────────
  # This is what your Flutter game connects to
  - hostname: nakama.yourdomain.com
    service: http://localhost:7350
    originRequest:
      # Nakama uses WebSockets for real-time — tell cloudflared to handle them
      proxyType: ""
      # No TLS between cloudflared and Nakama (they're on the same machine)
      noTLSVerify: false
      # How long to wait for Nakama to respond
      connectTimeout: 30s
      # Keep WebSocket connections alive
      keepAliveConnections: 100
      keepAliveTimeout: 90s
      # Disable chunked transfer for WebSocket compatibility
      disableChunkedEncoding: false

  # ── Console Dashboard ──────────────────────────────────────────────────────
  # Protected by Cloudflare Access (set up in Step 3.7)
  - hostname: nakama-console.yourdomain.com
    service: http://localhost:7352
    originRequest:
      connectTimeout: 30s

  # ── Catchall ──────────────────────────────────────────────────────────────
  # REQUIRED — cloudflared needs a fallback rule
  # Any request that doesn't match the above returns 404
  - service: http_status:404
```

---

## Step 3.6 — Run cloudflared as a System Service

```bash
# Install as a system service (cloudflared has a built-in installer)
sudo cloudflared service install

# The service reads from /etc/cloudflared/config.yml automatically
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

**Verify the tunnel is connected:**
```bash
cloudflared tunnel info nakama-colorplanes
# Should show: Status: healthy
```

**Test your domain:**
```bash
curl https://nakama.yourdomain.com/healthcheck
# Should return: {}
```

If this returns `{}` — your entire chain is working:
```
Your phone → Cloudflare CDN → Cloudflare Tunnel → cloudflared → Nakama → PostgreSQL
```

---

## Step 3.7 — Protect the Console with Cloudflare Access

Your Nakama console (`nakama-console.yourdomain.com`) should NOT be
publicly accessible. Anyone who finds the URL could try to brute-force it.

Cloudflare Access lets you put an email-verification gate in front of it
for free — no one sees the console unless they authenticate with your email.

1. Go to **Cloudflare Dashboard** → your domain → **Access** → **Applications**
2. Click **Add an Application** → **Self-hosted**
3. **Application name:** `Nakama Console`
4. **Application domain:** `nakama-console.yourdomain.com`
5. **Session duration:** `24 hours`
6. Under **Policies** → Add a policy:
   - **Action:** Allow
   - **Rule:** Emails → enter your email address
7. Save

Now anyone who visits `nakama-console.yourdomain.com` sees a Cloudflare
login screen first. Only your email can pass through.

---

## Step 3.8 — Verify WebSocket Connections Work

Cloudflare Tunnels support WebSockets, but you need to make sure it's
configured correctly. WebSockets are what Nakama uses for real-time game
play (the `onMatchData` stream in your Flutter code).

Test from your development machine:
```bash
# Install wscat if you don't have it
npm install -g wscat

# Test WebSocket connection to your Nakama server
wscat -c "wss://nakama.yourdomain.com/ws?token=YOUR_TEST_TOKEN"
```

If you see `Connected (press CTRL+C to quit)` — WebSockets work through
the tunnel.

---

---

# PART 4 — Log Rotation & Disk Management

## Step 4.1 — Configure Log Rotation

Your server has 256GB but logs can grow unbounded. Set up rotation now.

```bash
sudo nano /etc/logrotate.d/nakama
```

```
/opt/nakama/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 gomango gomango
    postrotate
        # Tell Nakama to reopen its log file after rotation
        docker kill --signal=USR1 nakama_server 2>/dev/null || true
    endscript
}

/var/log/cloudflared.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
```

Test the config:
```bash
sudo logrotate --debug /etc/logrotate.d/nakama
```

---

## Step 4.2 — Docker Log Cleanup

Docker stores container logs in `/var/lib/docker/containers/`. Without limits
these grow forever. You already set `max-size` in `docker-compose.yml`, but
also add global defaults:

```bash
sudo nano /etc/docker/daemon.json
```

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "dns": ["1.1.1.1", "8.8.8.8"]
}
```

```bash
sudo systemctl restart docker
# Wait a moment then bring the stack back up
cd /opt/nakama && docker compose up -d
```

---

---

# PART 5 — Automated Backups

## Step 5.1 — Database Backup Script

```bash
nano /opt/nakama/backups/backup.sh
chmod +x /opt/nakama/backups/backup.sh
```

```bash
#!/bin/bash
# /opt/nakama/backups/backup.sh
#
# Creates a compressed PostgreSQL dump, keeps last 7 days.
# Run daily via cron (configured in Step 5.2).

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
BACKUP_DIR="/opt/nakama/backups"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/nakama_${TIMESTAMP}.sql.gz"

# Load .env variables
source /opt/nakama/.env

# ── Run backup ────────────────────────────────────────────────────────────────
echo "[$(date)] Starting backup: ${BACKUP_FILE}"

docker exec nakama_postgres pg_dump \
  -U "${POSTGRES_USER}" \
  -d "${POSTGRES_DB}" \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists \
  | gzip > "${BACKUP_FILE}"

# Verify the file was created and is not empty
if [ ! -s "${BACKUP_FILE}" ]; then
  echo "[$(date)] ERROR: Backup file is empty or missing!" >&2
  exit 1
fi

FILE_SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
echo "[$(date)] Backup complete: ${FILE_SIZE}"

# ── Cleanup old backups ───────────────────────────────────────────────────────
DELETED=$(find "${BACKUP_DIR}" -name "nakama_*.sql.gz" -mtime +${RETENTION_DAYS} -print -delete | wc -l)
echo "[$(date)] Deleted ${DELETED} old backup(s)"

echo "[$(date)] Done."
```

**Test it manually:**
```bash
/opt/nakama/backups/backup.sh
ls -lah /opt/nakama/backups/
```

---

## Step 5.2 — Schedule Daily Backups with Cron

```bash
crontab -e
```

Add these lines:

```cron
# Nakama database backup — runs every day at 3:00 AM
0 3 * * * /opt/nakama/backups/backup.sh >> /opt/nakama/logs/backup.log 2>&1

# Weekly cleanup of Docker unused images (reclaims disk space)
0 4 * * 0 docker image prune -f >> /opt/nakama/logs/docker-cleanup.log 2>&1
```

Verify cron is scheduled:
```bash
crontab -l
```

---

## Step 5.3 — Restore from Backup (Know This Before You Need It)

```bash
# List available backups
ls -lah /opt/nakama/backups/

# Restore a specific backup (replace the filename)
gunzip -c /opt/nakama/backups/nakama_20260301_030000.sql.gz | \
  docker exec -i nakama_postgres psql \
    -U ${POSTGRES_USER} \
    -d ${POSTGRES_DB}
```

---

---

# PART 6 — Monitoring (htop + Simple Checks)

## Step 6.1 — System Health Aliases

Add these to your `.bashrc` so you can check everything with one command:

```bash
nano ~/.bashrc
```

Add at the bottom:

```bash
# ── Nakama Server Aliases ────────────────────────────────────────────────────

# Show status of all containers
alias nk-status='docker compose -f /opt/nakama/docker-compose.yml ps'

# Follow live logs from all containers
alias nk-logs='docker compose -f /opt/nakama/docker-compose.yml logs -f'

# Follow Nakama server logs only
alias nk-server-logs='docker logs -f nakama_server'

# Restart the stack
alias nk-restart='cd /opt/nakama && docker compose restart'

# Stop the stack
alias nk-stop='cd /opt/nakama && docker compose down'

# Start the stack
alias nk-start='cd /opt/nakama && docker compose up -d'

# Show resource usage
alias nk-stats='docker stats nakama_server nakama_postgres'

# Test if Nakama is responding
alias nk-health='curl -s http://localhost:7350/healthcheck && echo " ← Nakama healthy"'

# Check disk usage
alias nk-disk='du -sh /opt/nakama/* && df -h /dev/dm-0'

# View last 100 lines of backup log
alias nk-backup-log='tail -100 /opt/nakama/logs/backup.log'
```

Apply immediately:
```bash
source ~/.bashrc
```

---

## Step 6.2 — Simple Health Check Script

This script checks everything and gives you a clear status report.
Run it any time you want a snapshot of the server's health.

```bash
nano /opt/nakama/check-health.sh
chmod +x /opt/nakama/check-health.sh
```

```bash
#!/bin/bash
# /opt/nakama/check-health.sh
# Quick health report for the Nakama stack

echo "═══════════════════════════════════════"
echo "  NAKAMA STACK HEALTH CHECK"
echo "  $(date)"
echo "═══════════════════════════════════════"
echo ""

# ── Container Status ──────────────────────────────────────────────────────────
echo "📦 CONTAINERS:"
docker compose -f /opt/nakama/docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.RunningFor}}"
echo ""

# ── Nakama API ────────────────────────────────────────────────────────────────
echo "🎮 NAKAMA API:"
HEALTH=$(curl -s --max-time 5 http://localhost:7350/healthcheck 2>&1)
if [ "$HEALTH" = "{}" ]; then
  echo "  ✅ Responding on :7350"
else
  echo "  ❌ Not responding: $HEALTH"
fi
echo ""

# ── Cloudflare Tunnel ─────────────────────────────────────────────────────────
echo "☁️  CLOUDFLARE TUNNEL:"
TUNNEL_STATUS=$(systemctl is-active cloudflared)
if [ "$TUNNEL_STATUS" = "active" ]; then
  echo "  ✅ cloudflared is running"
else
  echo "  ❌ cloudflared is $TUNNEL_STATUS"
fi
echo ""

# ── Disk Space ────────────────────────────────────────────────────────────────
echo "💾 DISK USAGE:"
df -h /dev/dm-0 | tail -1 | awk '{print "  Used: "$3" / "$2" ("$5")"}'
echo "  Backups: $(du -sh /opt/nakama/backups/ 2>/dev/null | cut -f1)"
echo "  Logs:    $(du -sh /opt/nakama/logs/ 2>/dev/null | cut -f1)"
echo ""

# ── Memory ────────────────────────────────────────────────────────────────────
echo "🧠 MEMORY:"
free -h | grep Mem | awk '{print "  Total: "$2"  Used: "$3"  Free: "$4}'
echo ""

# ── Resource Usage ────────────────────────────────────────────────────────────
echo "📊 CONTAINER RESOURCES (5 second sample):"
docker stats --no-stream --format "  {{.Name}}: CPU {{.CPUPerc}} | MEM {{.MemUsage}}" \
  nakama_server nakama_postgres 2>/dev/null
echo ""

# ── Last Backup ───────────────────────────────────────────────────────────────
echo "💾 LAST BACKUP:"
LATEST=$(ls -t /opt/nakama/backups/nakama_*.sql.gz 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  echo "  $(basename $LATEST) — $(du -sh "$LATEST" | cut -f1)"
else
  echo "  ⚠️  No backups found"
fi
echo ""

echo "═══════════════════════════════════════"
```

```bash
/opt/nakama/check-health.sh
```

---

---

# PART 7 — Upgrading Nakama

When a new Nakama version is released (check https://github.com/heroiclabs/nakama/releases):

```bash
# 1. Edit docker-compose.yml — change the version tag
#    image: heroiclabs/nakama:3.22.0  →  heroiclabs/nakama:3.23.0

# 2. Pull the new image
cd /opt/nakama
docker compose pull

# 3. Restart (migration runs automatically on next start)
docker compose up -d

# 4. Verify
docker compose logs nakama | grep "Startup done"
```

**Never skip versions.** If you're on 3.20 and want 3.22, go 3.20 → 3.21 → 3.22.
Each version's migration script may depend on the previous version's schema.

---

---

# PART 8 — Flutter Game Integration

## Step 8.1 — Add Nakama to pubspec.yaml

You already have `nakama: ^1.1.0` in the plan. Here's the full section:

```yaml
# In your Flutter game's pubspec.yaml
dependencies:
  nakama: ^1.1.0
```

```bash
flutter pub get
```

---

## Step 8.2 — Environment Configuration

Your game needs to know the server URL. Hard-coding it is bad practice —
you want different URLs for development and production.

```dart
// lib/core/env.dart
//
// App environment configuration.
// Switch between dev (local) and prod (your Cloudflare domain) by
// passing --dart-define=ENVIRONMENT=prod when running the app.
//
// Usage:
//   flutter run --dart-define=ENVIRONMENT=dev    ← Local Nakama for testing
//   flutter run --dart-define=ENVIRONMENT=prod   ← Your live server
//   flutter build apk --dart-define=ENVIRONMENT=prod  ← Production build

class Env {
  Env._();

  // Read the environment at compile time
  // Default to 'dev' if not specified
  static const String _env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');

  static bool get isProduction => _env == 'prod';
  static bool get isDevelopment => _env == 'dev';

  // ── Server Configuration ───────────────────────────────────────────────────
  // For dev: your Nakama server accessible on local network
  //   If running on your own machine: localhost
  //   If on a different device on same LAN: 192.168.1.8
  //   If using Tailscale: mark2 (or whatever your Tailscale hostname is)
  //
  // For prod: your Cloudflare Tunnel domain
  static String get nakamaHost => isProduction
      ? 'nakama.yourdomain.com'
      : '192.168.1.8';

  static int get nakamaPort => isProduction
      ? 443     // HTTPS/WSS over Cloudflare
      : 7350;   // Direct HTTP for local dev

  static bool get nakamaSSL => isProduction;

  // The server key must match NAKAMA_SERVER_KEY in your .env file
  // NEVER commit the production key — use dart-define at build time
  static const String nakamaServerKey = String.fromEnvironment(
    'NAKAMA_SERVER_KEY',
    defaultValue: 'colorplanes-server-key-CHANGE-THIS-TOO', // dev default
  );
}
```

---

## Step 8.3 — Nakama Client Singleton

```dart
// lib/services/nakama_service.dart
//
// A singleton wrapper around the Nakama client.
// "Singleton" = only one instance exists for the entire app lifetime.
// This ensures you reuse the same HTTP connection pool.
//
// ACCESS ANYWHERE:
//   final nakama = NakamaService.instance;
//   final session = await nakama.authenticate(deviceId: 'abc');

import 'package:nakama/nakama.dart';
import 'package:colorplanes/core/env.dart';

class NakamaService {
  NakamaService._();

  static NakamaService? _instance;
  static NakamaService get instance {
    _instance ??= NakamaService._();
    return _instance!;
  }

  NakamaClient? _client;

  // Call this once at app startup (in main.dart or auth_provider)
  void initialize() {
    _client = getNakamaClient(
      host:      Env.nakamaHost,
      ssl:       Env.nakamaSSL,
      serverKey: Env.nakamaServerKey,
      // httpPort:  Env.nakamaPort is the default, only set if non-standard
    );
  }

  NakamaClient get client {
    assert(_client != null, 'NakamaService not initialised. Call initialize() first.');
    return _client!;
  }

  // ── Authentication ─────────────────────────────────────────────────────────
  // Device auth: uses the device's UUID as identity.
  // Same UUID = same account (good for returning players on same device).
  Future<Session> authenticateDevice(String deviceId) async {
    return await client.authenticateDevice(
      deviceId: deviceId,
      create:   true,       // Create account if it doesn't exist
    );
  }

  // ── Matchmaking ────────────────────────────────────────────────────────────
  // Add player to the matchmaker queue.
  // Nakama finds an opponent and creates a match.
  Future<MatchmakerTicket> joinMatchmaker({
    required Session session,
    required int     minCount,
    required int     maxCount,
  }) async {
    final socket = await client.createSocket();
    await socket.connect(session);

    return await socket.addMatchmaker(
      minCount: minCount,  // Minimum players to form a match
      maxCount: maxCount,  // Maximum players in a match
      // Optional: add skill-based properties later
      // stringProperties: {'skill_level': 'beginner'}
    );
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────
  Future<void> submitScore({
    required Session session,
    required String  leaderboardId,
    required int     score,
  }) async {
    await client.writeLeaderboardRecord(
      session:       session,
      leaderboardId: leaderboardId,
      score:         score,
    );
  }

  Future<LeaderboardRecordList> getTopScores({
    required Session session,
    required String  leaderboardId,
    int limit = 20,
  }) async {
    return await client.listLeaderboardRecords(
      session:       session,
      leaderboardId: leaderboardId,
      limit:         limit,
    );
  }

  // ── User Profile ───────────────────────────────────────────────────────────
  Future<Account> getAccount(Session session) async {
    return await client.getAccount(session);
  }

  Future<void> updateDisplayName(Session session, String name) async {
    await client.updateAccount(
      session:     session,
      displayName: name,
    );
  }
}
```

---

## Step 8.4 — Wire Nakama Into Auth Provider

Update `auth_provider.dart` to use NakamaService when in production:

```dart
// In AuthNotifier._init(), replace the future comment with:

Future<void> _init() async {
  _prefs = await SharedPreferences.getInstance();

  String? id   = _prefs.getString(StorageKeys.guestUserId);
  String? name = _prefs.getString(StorageKeys.displayName);
  int  hs      = _prefs.getInt(StorageKeys.highScore) ?? 0;

  if (id == null) {
    id = _uuid.v4();
    await _prefs.setString(StorageKeys.guestUserId, id);
  }

  // Try Nakama auth — falls back to guest if unavailable
  if (Env.isProduction) {
    try {
      NakamaService.instance.initialize();
      final session = await NakamaService.instance.authenticateDevice(id);
      final account = await NakamaService.instance.getAccount(session);

      // Cache the session for use in multiplayer
      _session = session;

      final user = UserModel(
        id:          account.user.id,
        displayName: account.user.displayName.isNotEmpty
                         ? account.user.displayName
                         : (name ?? 'Pilot'),
        highScore:   hs, // Local fallback until server score is synced
      );

      state = AuthAuthenticated(user);
      return; // Early return — Nakama auth succeeded
    } catch (e) {
      // Network unavailable or server down — fall back to guest mode
      // The game is still playable offline
      debugPrint('Nakama auth failed, using guest mode: $e');
    }
  }

  // Guest fallback (dev mode, or prod with no connection)
  state = AuthGuest(UserModel(id: id, displayName: name ?? 'Pilot', highScore: hs));
}

// Add this field to store the session
Session? _session;
Session? get session => _session;
```

---

## Step 8.5 — Test the Connection End-to-End

Run this from your development machine with the game pointing to your server:

```bash
# Development mode (local network)
flutter run --dart-define=ENVIRONMENT=dev

# Production mode (through Cloudflare Tunnel)
flutter run --dart-define=ENVIRONMENT=prod \
            --dart-define=NAKAMA_SERVER_KEY=your-actual-server-key
```

In the app, when it reaches HomeScreen:
- Check that the auth badge shows `● ONLINE` (not GUEST MODE)
- This means Nakama authentication succeeded

In your server logs:
```bash
ssh yarmuk
nk-server-logs
# You should see: {"level":"info","msg":"New user authenticated","uid":"..."}
```

---

---

# PART 9 — Security Hardening Checklist

Run through this before you consider the server "production ready":

## Step 9.1 — Change Default Credentials

```bash
# Verify your .env has strong passwords (NOT the example values)
grep -E "PASSWORD|KEY" /opt/nakama/.env

# Make sure none of them contain the word "CHANGE" anymore
grep "CHANGE" /opt/nakama/.env  # Should return nothing
```

## Step 9.2 — Verify Ports Are NOT Exposed

```bash
# Check what's listening and where
ss -tlnp | grep -E '7350|7351|7352|5432'
```

Expected output:
```
LISTEN  0  128  127.0.0.1:7350  ...  (Nakama API — localhost only ✅)
LISTEN  0  128  127.0.0.1:7351  ...  (Nakama gRPC — localhost only ✅)
LISTEN  0  128  127.0.0.1:7352  ...  (Console — localhost only ✅)
```

If you see `0.0.0.0:7350` instead of `127.0.0.1:7350` — STOP. Fix your
`docker-compose.yml` port bindings first.

## Step 9.3 — Verify Firewall is Active

```bash
sudo ufw status verbose
```

Expected output should show `Status: active` and no rules for ports
7350, 7351, or 7352.

## Step 9.4 — Verify fail2ban is Working

```bash
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

Should show `Currently banned: 0` (assuming no one has been brute-forcing).

## Step 9.5 — Check for Unprotected Config Files

```bash
# .env should be readable only by you
ls -la /opt/nakama/.env
# Expected: -rw------- 1 gomango gomango ...

# Tunnel credentials should also be protected
ls -la ~/.cloudflared/*.json
# Expected: -rw------- 1 gomango gomango ...
```

## Step 9.6 — Verify SSH Key-Only Auth

```bash
# From ANOTHER terminal, try to SSH with a password
ssh -o PreferredAuthentications=password gomango@192.168.1.8
# Expected: "Permission denied (publickey)"
```

---

---

# PART 10 — Performance Tuning for the i3-7100U

## Step 10.1 — PostgreSQL Memory Tuning

The default PostgreSQL config is designed for minimal memory usage.
On a 16GB machine you can give it much more, which speeds up queries.

```bash
# Connect to PostgreSQL
docker exec -it nakama_postgres psql -U nakama

-- Inside psql:
-- Check current settings
SHOW shared_buffers;
SHOW work_mem;
\q
```

Add a PostgreSQL configuration override to your Docker Compose:

```yaml
# Add to the postgres service in docker-compose.yml, under volumes:
      - /opt/nakama/config/postgres.conf:/etc/postgresql/postgresql.conf:ro
```

```bash
nano /opt/nakama/config/postgres.conf
```

```
# PostgreSQL tuning for 16GB RAM, game server workload
# Based on: https://pgtune.leopard.in.ua/ — DB Type: Online transaction processing

# Memory
shared_buffers = 2GB              # 12.5% of RAM — for PostgreSQL's own cache
effective_cache_size = 6GB        # How much OS cache PostgreSQL can assume exists
work_mem = 16MB                   # Per-sort/hash operation (not per-connection)
maintenance_work_mem = 512MB      # For VACUUM, CREATE INDEX, etc.

# WAL (Write-Ahead Log) — affects crash recovery speed
wal_buffers = 64MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9

# Connections — game servers have many short-lived connections
max_connections = 200

# Query planner
random_page_cost = 1.1            # SSD: set close to 1.0 (vs 4.0 for HDD)
effective_io_concurrency = 200    # SSD: high concurrency

# Parallel queries — i3 has 4 threads, use them
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
max_worker_processes = 4

# Logging — only log slow queries (>100ms) to avoid log spam
log_min_duration_statement = 100
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

After adding this, rebuild the postgres container:
```bash
cd /opt/nakama
docker compose down
docker compose up -d
docker compose logs postgres | grep "ready to accept connections"
```

## Step 10.2 — Kernel Network Tuning

These kernel parameters improve WebSocket connection handling at scale:

```bash
sudo nano /etc/sysctl.d/99-nakama.conf
```

```
# ── TCP/Network Tuning for Nakama Game Server ──────────────────────────────

# Increase the number of connections in the backlog queue
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# Increase TCP socket buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TIME_WAIT sockets — reduces "address already in use" errors under load
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Keep connections alive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# File descriptor limits — each WebSocket = 1 file descriptor
fs.file-max = 1000000
```

Apply immediately:
```bash
sudo sysctl -p /etc/sysctl.d/99-nakama.conf
```

## Step 10.3 — Increase File Descriptor Limit for Your User

```bash
sudo nano /etc/security/limits.d/nakama.conf
```

```
# Increase open file limits for gomango user
# Each WebSocket connection = 1 file descriptor
gomango    soft    nofile    65535
gomango    hard    nofile    65535
root       soft    nofile    65535
root       hard    nofile    65535
```

Log out and back in for this to take effect.

---

---

# PART 11 — Quick Reference Card

## Daily Commands

```bash
# Check everything is healthy
/opt/nakama/check-health.sh

# See live logs
nk-logs

# Restart the stack (after config changes)
nk-restart

# Graceful shutdown
nk-stop

# Start up
nk-start
```

## When Things Go Wrong

```bash
# Container won't start
docker compose -f /opt/nakama/docker-compose.yml logs nakama
docker compose -f /opt/nakama/docker-compose.yml logs postgres

# PostgreSQL won't accept connections
docker exec -it nakama_postgres pg_isready -U nakama

# Tunnel not connecting
sudo systemctl status cloudflared
journalctl -u cloudflared -n 50

# Ports check
ss -tlnp | grep -E '7350|7351|7352'

# Full system restart (nuclear option)
nk-stop
sudo systemctl restart docker
sleep 5
nk-start
```

## File Locations Reference

```
/opt/nakama/
├── .env                    ← Secrets — NEVER commit this to Git
├── docker-compose.yml      ← Service definitions
├── config/
│   ├── config.yml          ← Nakama configuration
│   └── postgres.conf       ← PostgreSQL tuning
├── data/                   ← Nakama runtime modules (Lua/JS — future)
├── postgres/               ← PostgreSQL data files
├── backups/
│   ├── backup.sh           ← Backup script
│   └── nakama_*.sql.gz     ← Daily backups
└── logs/
    ├── nakama.log          ← Nakama server logs
    └── backup.log          ← Backup job logs

/etc/cloudflared/
└── config.yml              ← Cloudflare Tunnel routes

~/.cloudflared/
└── *.json                  ← Tunnel credentials (keep this safe)
```

## Nakama Console Access (Quick)

```bash
# From your dev machine — SSH port forward
ssh -L 7352:localhost:7352 yarmuk -N &
# Then visit: http://localhost:7352
# Login: admin / [your NAKAMA_CONSOLE_PASSWORD]
```

Or directly via your Cloudflare-protected URL:
```
https://nakama-console.yourdomain.com
```

---

## Final Build Order Checklist

Run in this order. Don't proceed to the next step until the current one is verified.

| # | Step | Verify With |
|---|------|-------------|
| 1 | System updates + tools | `docker --version` works |
| 2 | Directory structure | `ls /opt/nakama/` shows all folders |
| 3 | UFW firewall | `sudo ufw status verbose` shows active |
| 4 | SSH hardened | New SSH session works after `sshd` restart |
| 5 | fail2ban active | `sudo fail2ban-client status` shows running |
| 6 | `.env` configured | No "CHANGE" strings remain in the file |
| 7 | `docker-compose.yml` created | File exists, no syntax errors |
| 8 | Nakama config.yml created | File exists, valid YAML |
| 9 | First `docker compose up -d` | `curl localhost:7350/healthcheck` returns `{}` |
| 10 | Systemd service enabled | Works after `sudo reboot` |
| 11 | Cloudflare Tunnel configured | `curl https://nakama.yourdomain.com/healthcheck` returns `{}` |
| 12 | Console behind Cloudflare Access | URL prompts for email login |
| 13 | Backup script tested | File appears in `/opt/nakama/backups/` |
| 14 | Cron scheduled | `crontab -l` shows backup job |
| 15 | Log rotation configured | `logrotate --debug` shows no errors |
| 16 | Flutter game connects | Auth badge shows `● ONLINE` |
| 17 | Security checklist passed | All ports show `127.0.0.1`, no "CHANGE" in .env |

---

*Your i3 laptop is now a proper game server.*
*Cloudflare handles TLS, routing, and DDoS protection.*
*Docker handles restarts and upgrades.*
*Systemd handles boot startup.*
*Cron handles backups.*
*You handle the game.*

**Good luck. 🛩️**
