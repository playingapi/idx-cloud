#!/bin/bash

# 创建 .workstation 目录
mkdir -p /home/user/.workstation

# 创建 customize_environment 脚本
cat << 'SCRIPT' > /home/user/.workstation/customize_environment
#!/bin/bash
# 以 root 执行 setup-server.sh
sudo -i bash -c 'export TAILSCALE_AUTH_KEY="$TAILSCALE_AUTH_KEY" GIT_TOKEN="$GIT_TOKEN"; wget -qO- https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/setup-server.sh | bash'
SCRIPT

# 设置执行权限
chmod +x /home/user/.workstation/customize_environment
