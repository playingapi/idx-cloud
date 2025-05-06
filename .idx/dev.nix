# 要了解更多关于如何使用 Nix 配置您的环境
# 请参阅：https://firebase.google.com/docs/studio/customize-workspace
{ pkgs, ... }: {
  # 系统环境变量
  env = {
    # Sing-box 配置（保留以便后续启用）
    ARGO_DOMAIN = "idx.cfsub.filegear-sg.me";
    UUID = "de04add9-5c68-8bab-950c-08cd5320df18";
    CDN = "skk.moe";
    NODE_NAME = "idx";
    VMESS_PORT = "60000";  # 端口范围 1000-65535
    VLESS_PORT = "60001";  # 端口范围 1000-65535

    # 节点信息的 Nginx 静态文件服务（保留以便后续启用）
    NGINX_PORT = "60010";  # 端口范围 1000-65535

    # Argo Tunnel 配置（保留以便后续启用）
    ARGO_TOKEN = "eyJhIjoiODllMDYzZWYxOGQ3ZmVjZjhlY2E2NTBiYWFjNzZjYmYiLCJ0IjoiN2JjZTEyNmItMjY3Yy00MTRlLWIxZjgtYTAzNzZiNmZhMDRmIiwicyI6Ik1HRTRaR05qWWpJdFl6Z3dNaTAwTWpFMExXRTBPV0V0WmpJME1XTmtaR00zT1daaCJ9";

    # SSH 配置
    SSH_PASSWORD = "123qwe!@#";

    # Tailscale 配置
    TAILSCALE_AUTH_KEY = ""; # 替换为您的 Tailscale 认证密钥

    # 远程端口配置（保留以便参考）
    UBUNTU_REMOTE_PORT = "6002"; # Tailscale 不直接使用
  };

  # 使用哪个 nixpkgs 频道
  channel = "stable-24.11"; # 或 "unstable"

  # 添加常用系统工具包
  packages = [
    # 基础系统工具
    pkgs.debianutils        # Debian 系统实用工具集
    pkgs.uutils-coreutils-noprefix  # Rust 实现的核心工具集
    pkgs.gnugrep            # GNU 文本搜索工具
    pkgs.openssl            # SSL/TLS 加密工具
    pkgs.screen             # 终端多窗口管理器
    pkgs.qrencode           # 二维码生成工具

    # 系统监控和管理
    pkgs.procps             # 进程监控工具集（ps, top 等）
    pkgs.nettools           # 网络配置工具集
    pkgs.rsync              # 文件同步工具
    pkgs.psmisc             # 进程管理工具集（killall, pstree 等）
    pkgs.htop               # 交互式进程查看器
    pkgs.iotop              # IO 监控工具

    # 开发工具
    pkgs.gcc                # GNU C/C++ 编译器
    pkgs.gnumake            # GNU 构建工具
    pkgs.cmake              # 跨平台构建系统
    pkgs.python3            # Python 3 编程语言
    pkgs.openssh            # SSH 连接工具
    pkgs.nano               # 简单文本编辑器

    # 文件工具
    pkgs.file               # 文件类型识别工具
    pkgs.tree               # 目录树显示工具
    pkgs.zip                # 文件压缩工具

    # 网络代理工具
    pkgs.cloudflared        # Cloudflare 隧道客户端（保留以便后续启用）
    pkgs.xray               # 代理工具
    pkgs.sing-box           # 通用代理平台（保留以便后续启用）
    pkgs.tailscale          # Tailscale 内网穿透工具
  ];

  # 服务配置
  services = {
    # 启用 Docker 服务
    docker.enable = true;
  };

  idx = {
    # 搜索扩展程序: https://open-vsx.org/ 并使用 "publisher.id"
    extensions = [
      # 添加您需要的扩展
    ];

    # 启用预览
    previews = {
      enable = true;
      previews = {
        # 预览配置
      };
    };

    # 工作区生命周期钩子
    workspace = {
      # 工作区首次创建时运行
      onCreate = {
        default.openFiles = [ ".idx/dev.nix" "README.md" ];
      };

      # 工作区(重新)启动时运行
      onStart = {
        # 创建配置文件目录（保留以便后续启用 Sing-box 和 Nginx）
        init-01-mkdir = "[ -d conf ] || mkdir conf; [ -d sing-box ] || mkdir sing-box; [ ! -f sing-box/node.txt ] && touch sing-box/node.txt";

        # 检查并创建 nginx 配置（保留以便后续启用）
        init-02-nginx = ''
          cat > nginx.conf << EOF
          user  nginx;
          worker_processes  auto;

          error_log  /dev/null;
          pid        /var/run/nginx.pid;

          events {
              worker_connections  1024;
          }

          http {
              include       /etc/nginx/mime.types;
              default_type  application/octet-stream;
              charset utf-8;

              access_log  /dev/null;

              sendfile        on;

              keepalive_timeout  65;

              #gzip  on;

              server {
                  listen       $NGINX_PORT;
                  server_name  localhost;

                  # 严格匹配 /\$UUID/node 路径
                  location = /\$UUID/node {
                      alias   /data/node.txt;
                      default_type text/plain;
                      charset utf-8;
                      add_header Content-Type 'text/plain; charset=utf-8';
                  }

                  # 拒绝其他所有请求
                  location / {
                      return 403;
                  }

                  # 错误页面配置
                  error_page   500 502 503 504  /50x.html;
                  location = /50x.html {
                      root   /usr/share/nginx/html;
                  }
              }
          }
          EOF
        '';

        # 检查并创建 SSL 证书（保留以便后续启用 Sing-box）
        init-02-ssl-cert = "[ -f sing-box/cert/private.key ] || (mkdir -p sing-box/cert && openssl ecparam -genkey -name prime256v1 -out sing-box/cert/private.key && openssl req -new -x509 -days 36500 -key sing-box/cert/private.key -out sing-box/cert/cert.pem -subj \"/CN=$(awk -F . '{print $(NF-1)\".\"$NF}' <<< \"$ARGO_DOMAIN\")\")";

        # 检查并创建 sing-box 配置（保留以便后续启用）
        init-02-singbox = ''
          cat > config.json << EOF
{
    "dns":{
        "servers":[
            {
                "type":"local"
            }
        ],
        "strategy": "ipv4_only"
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "/etc/sing-box/cache.db"
        }
    },
    "ntp": {
        "enabled": true,
        "server": "time.apple.com",
        "server_port": 123,
        "interval": "60m"
    },
    "inbounds": [
        {
            "type":"vmess",
            "tag":"vmess-in",
            "listen":"::",
            "listen_port":$VMESS_PORT,
            "tcp_fast_open":false,
            "proxy_protocol":false,
            "users":[
                {
                    "uuid":"$UUID",
                    "alterId":0
                }
            ],
            "transport":{
                "type":"ws",
                "path":"/$UUID-vmess",
                "max_early_data":2048,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            },
            "tls": {
                "enabled": true,
                "server_name": "$ARGO_DOMAIN",
                "certificate_path": "/etc/sing-box/cert/cert.pem",
                "key_path": "/etc/sing-box/cert/private.key"
            },
            "multiplex":{
                "enabled":true,
                "padding":true,
                "brutal":{
                    "enabled":false,
                    "up_mbps":1000,
                    "down_mbps":1000
                }
            }
        },
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": $VLESS_PORT,
            "users": [
                {
                    "uuid": "$UUID",
                    "flow": ""
                }
            ],
            "transport": {
                "type": "ws",
                "path": "/$UUID-vless",
                "max_early_data": 2048,
                "early_data_header_name": "Sec-WebSocket-Protocol"
            },
            "tls": {
                "enabled": true,
                "server_name": "$ARGO_DOMAIN",
                "certificate_path": "/etc/sing-box/cert/cert.pem",
                "key_path": "/etc/sing-box/cert/private.key"
            },
            "multiplex": {
                "enabled":true,
                "padding":true
            }
        }
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

          # 创建 node.txt 文件
          cat > node.txt << EOF
浏览器访问节点信息: https://$ARGO_DOMAIN/$UUID/node

-------------------------------------

V2RayN:

vmess://$(echo -n '{"v":"2","ps":"'$NODE_NAME' vmess","add":"'$CDN'","port":"443","id":"'$UUID'","aid":"0","scy":"none","net":"ws","type":"none","host":"'$ARGO_DOMAIN'","path":"/'$UUID'-vmess","tls":"tls","sni":"'$ARGO_DOMAIN'","alpn":"","fp":"chrome"}' | base64 -w0)

vless://$UUID@$CDN:443?encryption=none&security=tls&sni=$ARGO_DOMAIN&fp=chrome&type=ws&host=$ARGO_DOMAIN&path=%2F$UUID-vless#$NODE_NAME%20vless

-------------------------------------

NekoBox:

vmess://$(echo -n '{"add":"'$CDN'","aid":"0","host":"'$ARGO_DOMAIN'","id":"'$UUID'","net":"ws","path":"/'$UUID'-vmess","port":"443","ps":"'$NODE_NAME' vmess","scy":"none","sni":"'$ARGO_DOMAIN'","tls":"tls","type":"","v":"2"}' | base64 -w0)

vless://$UUID@$CDN:443?security=tls&sni=$ARGO_DOMAIN&fp=chrome&type=ws&path=/$UUID-vless&host=$ARGO_DOMAIN&encryption=none#$NODE_NAME%20vless

-------------------------------------

Shadowrocket:

vmess://$(echo -n "none:$UUID@$CDN:443" | base64 -w0)?remarks=$NODE_NAME%20vmess&obfsParam=%7B%22Host%22:%22$ARGO_DOMAIN%22%7D&path=/$UUID-vmess?ed=2048&obfs=websocket&tls=1&peer=$ARGO_DOMAIN&mux=1&alterId=0

vless://$(echo -n "auto:$UUID@$CDN:443" | base64 -w0)?remarks=$NODE_NAME%20vless&obfsParam=%7B%22Host%22:%22$ARGO_DOMAIN%22%7D&path=/$UUID-vless?ed=2048&obfs=websocket&tls=1&peer=$ARGO_DOMAIN&allowInsecure=1&mux=1

-------------------------------------

Clash:

proxies:
  - name: "$NODE_NAME vmess"
    type: vmess
    server: "$CDN"
    port: 443
    uuid: "$UUID"
    alterId: 0
    cipher: none
    tls: true
    servername: "$ARGO_DOMAIN"
    skip-cert-verify: false
    network: ws
    ws-opts:
      path: "/$UUID-vmess"
      headers:
        Host: "$ARGO_DOMAIN"
      max-early-data: 2048
      early-data-header-name: Sec-WebSocket-Protocol
    smux:
      enabled: true
      protocol: 'h2mux'
      padding: true
      max-connections: '8'
      min-streams: '16'
      statistic: true
      only-tcp: false
    tfo: false

  - name: "$NODE_NAME vless"
    type: vless
    server: "$CDN"
    port: 443
    uuid: "$UUID"
    tls: true
    servername: "$ARGO_DOMAIN"
    skip-cert-verify: false
    network: ws
    ws-opts:
      path: "/$UUID-vless"
      headers:
        Host: "$ARGO_DOMAIN"
      max-early-data: 2048
      early-data-header-name: Sec-WebSocket-Protocol
    smux:
      enabled: true
      protocol: 'h2mux'
      padding: true
      max-connections: '8'
      min-streams: '16'
      statistic: true
      only-tcp: false
    tfo: false

-------------------------------------

SingBox:

{
    "outbounds": [
        {
            "tag": "$NODE_NAME vmess",
            "type": "vmess",
            "server": "$CDN",
            "server_port": 443,
            "uuid": "$UUID",
            "alter_id": 0,
            "security": "none",
            "network": "tcp",
            "tcp_fast_open": false,
            "transport": {
                "type": "ws",
                "path": "/$UUID-vmess",
                "headers": {
                    "Host": "$ARGO_DOMAIN"
                }
            },
            "tls": {
                "enabled": true,
                "insecure": false,
                "server_name": "$ARGO_DOMAIN",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "multiplex": {
                "enabled": true,
                "protocol": "h2mux",
                "max_streams": 16,
                "padding": true
            }
        },
        {
            "type": "vless",
            "tag": "$NODE_NAME vless",
            "server": "$CDN",
            "server_port": 443,
            "uuid": "$UUID",
            "network": "tcp",
            "tcp_fast_open": false,
            "tls": {
                "enabled": true,
                "insecure": false,
                "server_name": "$ARGO_DOMAIN",
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "multiplex": {
                "enabled": true,
                "protocol": "h2mux",
                "max_streams": 16,
                "padding": true
            }
        }
    ]
}
EOF
          # 把所有的配置文件移到 sing-box 工作目录
          rm -rf sing-box/{nginx.conf,config.json,node.txt}
          mv nginx.conf config.json node.txt sing-box/
        '';

        # 配置并启动 Tailscale
        tailscale-setup = ''
          # 确保 Tailscale 已安装
          if ! command -v tailscale >/dev/null 2>&1; then
            echo "Tailscale 未找到，请确保在 packages 中包含 tailscale"
            exit 1
          fi

          # 清理旧的 Tailscale 状态文件，避免 socket 错误
          echo "清理旧的 Tailscale 状态文件..."
          rm -f /home/user/.local/share/tailscale/tailscaled.sock || true

          # 检查并终止已有 tailscaled 进程
          if pgrep tailscaled >/dev/null; then
            echo "发现已有 tailscaled 进程，正在终止..."
            pkill -f tailscaled || true
            sleep 2
          fi

          # 启动 tailscaled，使用用户空间网络和内存状态
          echo "正在启动 tailscaled..."
          tailscaled --tun=userspace-networking --state=mem: &

          # 等待 tailscaled 启动
          sleep 5

          # 检查 tailscaled 是否运行
          if ! pgrep tailscaled >/dev/null; then
            echo "启动 tailscaled 失败，请检查日志"
            exit 1
          fi
          echo "tailscaled 已运行"

          # 认证并配置 Tailscale
          echo "正在配置 Tailscale..."
          if [ -n "$TAILSCALE_AUTH_KEY" ]; then
            tailscale up --auth-key="$TAILSCALE_AUTH_KEY" --advertise-exit-node --accept-dns=false --accept-routes --reset || {
              echo "Tailscale 认证失败，请检查 TAILSCALE_AUTH_KEY 或网络连接"
              exit 1
            }
          else
            echo "未设置 TAILSCALE_AUTH_KEY，请手动运行 'tailscale up --accept-dns=false --advertise-exit-node --accept-routes --reset' 进行认证"
            exit 1
          fi

          # 验证 Tailscale 状态
          tailscale status
          echo "SSH 服务可通过以下 Tailscale IP 和端口访问："
          tailscale ip -4
          echo "端口：9022"
        '';

        # 检查并创建 docker compose 配置文件
        init-02-compose = ''
          cat > docker-compose.yml << 'EOF'
services:
  ubuntu:
    image: ubuntu:latest
    container_name: ubuntu
    hostname: ubuntu
    networks:
      - idx
    ports:
      - "9022:22"  # 映射宿主机 9022 端口到容器 22 端口
    volumes:
      - ubuntu_data:/root/data
      - ./sing-box/node.txt:/root/data/node.txt:ro
    tty: true
    restart: unless-stopped
    command: |
      bash -c "
        export DEBIAN_FRONTEND=noninteractive &&
        apt update && apt install -y openssh-server net-tools systemd &&
        echo \"root:$SSH_PASSWORD\" | chpasswd &&
        sed -i 's/#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config &&
        sed -i 's/#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config &&
        sed -i 's/#*UsePAM.*/UsePAM no/' /etc/ssh/sshd_config &&
        mkdir -p /var/run/sshd &&
        # 检查 SSH 配置
        sshd -t 2> /tmp/sshd_error.log || { echo 'SSH 配置错误'; cat /tmp/sshd_error.log; exit 1; } &&
        # 启动 SSH 服务
        service ssh start &&
        # 验证 SSH 端口
        netstat -tuln | grep 22 || { echo 'SSH 端口未监听'; exit 1; } &&
        echo 'SSH 服务已启动，可通过宿主机的 Tailscale IP（端口 9022）访问' &&
        # 捕获 SSH 日志
        journalctl -u ssh -f
      "

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    command: tunnel --edge-ip-version auto run --token $ARGO_TOKEN
    networks:
      - idx
    volumes:
      - cloudflared_data:/etc/cloudflared
    restart: unless-stopped

  sing-box:
    image: fscarmen/sing-box:pre
    container_name: sing-box
    networks:
      - idx
    volumes:
      - ./sing-box:/etc/sing-box
    command: run -c /etc/sing-box/config.json
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    container_name: nginx
    networks:
      - idx
    volumes:
      - ./sing-box/node.txt:/data/node.txt:ro
      - ./sing-box/nginx.conf:/etc/nginx/nginx.conf:ro
    restart: unless-stopped

###  nezha-agent:
###    image: fscarmen/nezha-agent:latest
###    container_name: nezha-agent
###    pid: host        # 使用主机 PID 命名空间
###    volumes:
###      - /:/host:ro     # 挂载主机根目录
###      - /proc:/host/proc:ro  # 挂载主机进程信息
###      - /sys:/host/sys:ro    # 挂载主机系统信息
###      - /etc:/host/etc:ro    # 挂载主机配置
###    environment:
###      - NEZHA_SERVER=$NEZHA_SERVER
###      - NEZHA_PORT=$NEZHA_PORT
###      - NEZHA_KEY=$NEZHA_KEY
###      - NEZHA_TLS=$NEZHA_TLS
###    command: -s $NEZHA_SERVER:$NEZHA_PORT -p $NEZHA_KEY $NEZHA_TLS
###    restart: unless-stopped

networks:
  idx:
    driver: bridge

volumes:
  ubuntu_data:
  cloudflared_data:
EOF
        '';

        # 启动服务（仅启动 Ubuntu）
        start-compose = "docker compose up -d";
        start-node = "cat sing-box/node.txt";
      };
    };
  };
}
