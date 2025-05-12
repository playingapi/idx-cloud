#!/bin/bash

# 定义关键路径
script="/home/user/.workstation/customize_environment"
log_file="/var/log/customize_environment"

# 检查环境变量
if [ -z "${TAILSCALE_AUTH_KEY}" ] || [ -z "${GIT_TOKEN}" ]; then
  sudo sh -c "echo 'Error: TAILSCALE_AUTH_KEY or GIT_TOKEN not set at $(date)' >> '${log_file}'"
  exit 1
fi

# 创建 .workstation 目录
mkdir -p /home/user/.workstation

# 等待网络连接
sudo sh -c "echo 'Checking network connectivity at $(date)' >> '${log_file}'"
until ping -c 1 github.com >/dev/null 2>&1; do
  sudo sh -c "echo 'Waiting for network...' >> '${log_file}'"
  sleep 5
done
sudo sh -c "echo 'Network is up at $(date)' >> '${log_file}'"

# 创建 customize_environment 脚本，安全替换环境变量
cat << EOF > "${script}"
#!/bin/bash
# 记录开始时间
sudo sh -c "echo '[customize_environment] Starting at \$(date)' >> '${log_file}'"

# 以 root 执行 setup-server.sh，不记录输出，绕过缓存
sudo -i /bin/bash -c "export TAILSCALE_AUTH_KEY='\${TAILSCALE_AUTH_KEY}' GIT_TOKEN='\${GIT_TOKEN}'; bash <(wget -qO- 'https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/setup-server.sh)"

# 记录完成
sudo sh -c "echo '[customize_environment] Completed at \$(date)' >> '${log_file}'"
EOF

# 设置执行权限
chmod +x "${script}"

# 打印生成脚本内容（用于调试）
cat "${script}"

