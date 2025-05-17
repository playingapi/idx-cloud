#!/bin/bash

# Colors for output
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"

# Header & Footer
print_header() {
echo -e "${CYAN}"
echo "============================================"
echo "         🔧 SERVER AUTO CONFIG SCRIPT        "
echo "============================================"
echo -e "${RESET}"
}

print_footer() {
echo -e "${CYAN}"
echo "============================================"
echo "      ✅ SETUP COMPLETED SUCCESSFULLY       "
echo "============================================"
echo -e "${RESET}"
}

# Logging Steps
print_step() { echo -e "${YELLOW}▶️  $1${RESET}"; }
print_success() { echo -e "${GREEN}✔ $1${RESET}"; }
print_error() { echo -e "${RED}✖ $1${RESET}"; }


# Start
print_header


### STEP 3: Change root password ###
print_step "Changing root password..."

echo "root:123qwe!@#" | chpasswd && print_success "Root password changed to '123qwe!@#'" || print_error "Failed to change root password"



print_step "install zsh"

sudo apt-get update
sudo apt-get install zsh -y


print_step "install ohmyzsh"


rm -rf ~/.oh-my-zsh
echo y | sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/.p10k.zsh -O ~/.p10k.zsh


print_step "install config file"

sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
locale-gen zh_CN.UTF-8

wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/.bashrc -O ~/.bashrc
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/.zshrc -O ~/.zshrc

apt install -y curl
apt install -y sshpass
apt install -y jq


print_step "install tmux"

sudo apt-get install tmux -y

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/.tmux.conf -O ~/.tmux.conf


token="$GIT_TOKEN"

echo "GIT_TOKEN: $GIT_TOKEN"

if [ -z "$token" ]; then
    echo "no git token"
else
    echo "git token found"
    #export GIT_TOKEN="$token"; bash <(wget -qO- https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/clone-xdl.sh)
fi

print_step "new idx session"

tmux new-session -s idx -d -n "" -c ~/xdl

tmux ls

export PROMPT_COMMAND=""

print_step "tmux att -t idx"
#tmux att -t idx
#tmux a
#tmux detach



### STEP 5: Install and start Tailscale ###
print_step "Checking Tailscale installation..."

if ! command -v tailscale &>/dev/null; then
  print_step "Tailscale not found. Installing..."
  #curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
  curl -fsSL https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/tailscale-install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
else
  print_success "Tailscale is already installed"
fi

print_step "Enabling and starting tailscaled service..."

#print_step "systemctl enable tailscaled"
#systemctl enable tailscaled >/dev/null 2>&1
#sleep 3

#print_step "systemctl stop tailscaled"
#systemctl stop tailscaled >/dev/null 2>&1
#sleep 3

#print_step "systemctl start tailscaled"
#systemctl start tailscaled >/dev/null 2>&1

if [ -n "$TS_API_KEY" ]; then
    print_step "Checking Offline Device..."
    TAILNET="${TS_TAILNET:-playingapi@gmail.com}"
    echo "Using Tailnet: $TAILNET"
    HOSTNAME_PART=$(uname -n | cut -d'-' -f2)
    echo "Hostname part: $HOSTNAME_PART"

    curl -s -u "$TS_API_KEY:" "https://api.tailscale.com/api/v2/tailnet/$TAILNET/devices?fields=all" | \
    jq -c '.devices[]' | while IFS= read -r device; do
        device_name=$(echo "$device" | jq -r '.hostname')
        device_id=$(echo "$device" | jq -r '.nodeId')
        device_name_part=$(echo "$device_name" | cut -d'-' -f2)

        if [[ "$device_name" =~ idx|firebase && "$device_name_part" = "$HOSTNAME_PART" ]]; then
            echo "Found matching device: $device_name (ID: $device_id, Part: $device_name_part)"
            echo "Attempting to delete device: $device_id"
            response=$(curl -s -u "$TS_API_KEY:" -X DELETE "https://api.tailscale.com/api/v2/device/$device_id")
	    sleep 2
        fi
    done
fi



# 尝试启动 tailscaled，最多重试 3 次
print_step "启动 tailscaled with --state=mem:..."
max_attempts=3
attempt=1
base_wait_time=0
INCREMENT_RANGE=3  # 控制随机增加的时间范围（1到此值秒）
INITIAL_WAIT_RANGE=6  # 控制初次等待的随机范围（5到4+此值秒）
LOG_FILE="/tmp/tailscaled.log"  # 日志文件路径

while [ $attempt -le $max_attempts ]; do
    # 检查并杀死现有 tailscaled 进程
    if pgrep tailscaled >/dev/null; then
        print_step "杀死现有 tailscaled 进程..."
        pkill -f tailscaled >/dev/null 2>&1
        sleep 4
        if pgrep tailscaled >/dev/null; then
            print_error "无法杀死现有 tailscaled 进程，程序退出"
            exit 1
        else
            print_success "现有 tailscaled 进程已杀死"
        fi
    else
        print_success "未找到现有 tailscaled 进程, 尝试启动"
    fi

    # 启动 tailscaled 并记录日志
    nohup tailscaled --state=mem: >"$LOG_FILE" 2>&1 &
    tailscaled_pid=$!
    print_step "tailscaled 启动，PID: $tailscaled_pid"

    # 随机等待时间：第一次5到4+INITIAL_WAIT_RANGE秒，后续在之前基础上增加1-INCREMENT_RANGE秒
    if [ $attempt -eq 1 ]; then
        wait_time=$((RANDOM % $INITIAL_WAIT_RANGE + 5))
    else
        increment=$((RANDOM % $INCREMENT_RANGE + 1))
        wait_time=$((base_wait_time + increment))
    fi
    base_wait_time=$wait_time
    print_step "等待 $wait_time 秒以检查进程状态..."
    sleep $wait_time

    # 检查 tailscaled 进程状态
    print_step "检查 tailscaled 进程状态..."
    if pgrep tailscaled >/dev/null || ps -p $tailscaled_pid >/dev/null; then
        print_success "tailscaled 进程正在运行"
        break
    else
        print_error "tailscaled 进程启动失败 (尝试 $attempt/$max_attempts)，检查日志 $LOG_FILE"
        if [ $attempt -eq $max_attempts ]; then
            print_error "达到最大重试次数，程序退出"
            exit 1
        fi
        ((attempt++))
    fi
done

print_step "Bringing up Tailscale (you may need to authenticate)..."
print_step "tailscale down"

tailscale down

sleep 3

# 启用IP转发
echo "启用IP转发..."
if [ -d "/etc/sysctl.d" ]; then
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf
sysctl -p /etc/sysctl.d/99-tailscale.conf
else
echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
sysctl -p /etc/sysctl.conf
fi

# 检查firewalld并启用伪装（如果需要）
if command -v firewall-cmd &> /dev/null; then
echo "检测到firewalld，启用伪装..."
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload
fi



print_step "tailscale up"

#tailscale up


echo "TS_AUTH_KEY: $TS_AUTH_KEY"

if [ -z "$TS_AUTH_KEY" ]; then
tailscale up --advertise-exit-node
else
tailscale up --auth-key="$TS_AUTH_KEY"  --advertise-exit-node
fi

sleep 3

# 启用Funnel
echo "启用Tailscale Funnel（beta功能）..."
echo "首次启用Funnel需要通过浏览器验证，请按照CLI提示访问URL（如 https://login.tailscale.com/f/funnel?node=xxx）"
echo "为减少验证，可预配置ACL，在Access Controls页面添加："
echo '{
"nodeAttrs": [
{ "target": ["autogroup:member"], "attr": ["funnel"] }
]
}'

# tailscale funnel on

# 提示用户手动在网页端允许exit node和配置Funnel
echo "设备已设置为exit node并启用了Funnel，请完成以下配置："
echo "1. 访问 https://login.tailscale.com/admin"
echo "2. 配置exit node："
echo "   - 在 Machines 页面找到此设备"
echo "   - 点击 ... 图标，选择 Edit route settings，启用 Use as exit node（如果未自动批准）"
echo "3. 确认Access Controls 页面包含以下规则："
echo '{
"acls": [
{ "action": "accept", "src": ["autogroup:member"], "dst": ["autogroup:internet:*"] }
],
"nodeAttrs": [
{ "target": ["autogroup:member"], "attr": ["funnel"] }
],
"autoApprovers": {
"exitNode": ["your-email@example.com"]
}
}'
echo "   - 将 your-email@example.com 替换为你的Tailscale账户邮箱"
echo "   - 注意：如果ACL包含 {\"action\": \"accept\", \"src\": [\"*\"], \"dst\": [\"*:*\"]}，exit node规则可省略"
echo "   - 如果不使用autoApprovers，可手动批准exit node，删除autoApprovers部分"
echo "4. 保存后，exit node 和 Funnel 即可使用"
echo "5. 手动暴露Funnel服务以允许任何人访问："
echo "   - 启动本地服务，例如：python3 -m http.server 3000"
echo "   - 运行：tailscale funnel 3000 / tailscale funnel --bg 3000"
echo "   - 获取Funnel URL（例如 https://<node-name>.<tailnet-name>.ts.net），默认通过443端口访问"
echo "   - 任何人可通过该URL访问服务，无需Tailscale账户"
echo "   - 注意：Funnel对外端口限于443、8443、10000，但可代理到任何本地端口（如3000）"
echo "   - 无法同时暴露多个端口，建议使用反向代理（如Nginx）分发多个服务"
echo "   - 确保本地服务端口未被占用，防火墙允许Tailscale流量（通常无需开放443等端口）"
echo "   - 验证状态：tailscale funnel status"
echo "   - 停止Funnel：tailscale funnel 3000 off 或 tailscale funnel off"

print_step "tailscale status"

tailscale status


print_step "tailscale ip"

tailscale ip


### STEP : Kill SSSD ###
print_step "Kill SSHD"

# Find the PID and process name of the process listening on port 22
PROCESS_INFO=$(lsof -i :22 -F pc | grep '^p' -A1)

# Extract PID and process name
PID=$(echo "$PROCESS_INFO" | grep '^p' | cut -d'p' -f2)
PROCESS_NAME=$(echo "$PROCESS_INFO" | grep '^c' | cut -d'c' -f2)

# Check if PID was found
if [ -z "$PID" ]; then
echo "No process found listening on port 22."
else
# Print PID and process name
echo "Found process: $PROCESS_NAME (PID: $PID)"

# Kill the process with SIGKILL (-9)
kill -9 "$PID"

# Verify if the process was killed
if [ $? -eq 0 ]; then
echo "Process $PROCESS_NAME with PID $PID has been terminated."
else
echo "Failed to terminate process $PROCESS_NAME with PID $PID."
fi

fi

# Find the PID and process name of the process listening on port 9022
PROCESS_INFO=$(lsof -i :9022 -F pc | grep '^p' -A1)

# Extract PID and process name
PID=$(echo "$PROCESS_INFO" | grep '^p' | cut -d'p' -f2)
PROCESS_NAME=$(echo "$PROCESS_INFO" | grep '^c' | cut -d'c' -f2)

# Check if PID was found
if [ -z "$PID" ]; then
echo "No process found listening on port 9022."
else
# Print PID and process name
echo "Found process: $PROCESS_NAME (PID: $PID)"

# Kill the process with SIGKILL (-9)
kill -9 "$PID"

# Verify if the process was killed
if [ $? -eq 0 ]; then
echo "Process $PROCESS_NAME with PID $PID has been terminated."
else
echo "Failed to terminate process $PROCESS_NAME with PID $PID."
fi

fi



### Last STEP: SSH Configuration ###
print_step "Configuring SSH to allow root login and password authentication..."

mkdir -p ~/.ssh
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/ssh_config -O ~/.ssh/config


SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup existing SSH config
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

cat "$SSHD_CONFIG"

# Ensure the file ends with a newline
if [ -n "$(tail -c 1 "$SSHD_CONFIG")" ]; then
echo >> "$SSHD_CONFIG"
fi

# Update settings if they exist
sed -i '/^#\?PermitRootLogin\b/s/.*/PermitRootLogin yes/' "$SSHD_CONFIG"
sed -i '/^#\?PasswordAuthentication\b/s/.*/PasswordAuthentication yes/' "$SSHD_CONFIG"
sed -i '/^#\?PubkeyAuthentication\b/s/.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
sed -i '/^#\?UsePAM\b/s/.*/UsePAM no/' "$SSHD_CONFIG"
sed -i '/^#\?Port\b/s/.*/Port 9022/' "$SSHD_CONFIG"

# Add settings if missing
grep -q "^PermitRootLogin" "$SSHD_CONFIG" || echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
grep -q "^PasswordAuthentication" "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"
grep -q "^PubkeyAuthentication" "$SSHD_CONFIG" || echo "PubkeyAuthentication yes" >> "$SSHD_CONFIG"
grep -q "^UsePAM" "$SSHD_CONFIG" || echo "UsePAM no" >> "$SSHD_CONFIG"
grep -q "^Port" "$SSHD_CONFIG" || echo "Port 9022" >> "$SSHD_CONFIG"

print_success "SSH configuration updated"

cat "$SSHD_CONFIG"

### STEP 2: Unmask & Restart SSH ###
print_step "Unmasking and restarting SSH service..."

# Unmask và enable SSH service
systemctl unmask ssh >/dev/null 2>&1
systemctl unmask ssh.socket >/dev/null 2>&1
systemctl enable ssh >/dev/null 2>&1
systemctl enable ssh.socket >/dev/null 2>&1


print_step "systemctl restart ssh"
print_step "systemctl restart ssh.socket"

# Khởi động lại dịch vụ SSH
if systemctl restart ssh >/dev/null 2>&1 && systemctl restart ssh.socket >/dev/null 2>&1; then
print_success "SSH service and socket restarted successfully"
systemctl status ssh
else
print_error "Failed to restart SSH service or socket. Check systemctl status for more details."
fi


print_step "lsof -i :9022"
lsof -i :9022

sleep 2

### STEP 4: Docker & containerd ###
print_step "Unmasking and starting Docker & containerd..."

wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/setup-docker.sh -O ~/setup-docker.sh
chmod 777 ~/setup-docker.sh
~/setup-docker.sh

sleep 5


print_step "install firefox for keep idx alive"
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/setup-firefox.sh -O ~/setup-firefox.sh
chmod 777 ~/setup-firefox.sh
~/setup-firefox.sh


#read -p "Do you want to run keep-alive.sh? (y/N): " response

#if [[ "$response" =~ ^[Yy]$ ]]; then
echo "Running keep-alive.sh..."
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/keep-alive.sh -O ~/keep-alive.sh
chmod 777 ~/keep-alive.sh
#~/keep-alive.sh &
nohup ~/keep-alive.sh >/dev/null 2>&1 &

#fi


wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/oalive.sh -O ~/oalive.sh
chmod 777 ~/oalive.sh


wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/onekey-NeverIdle.sh -O ~/onekey-NeverIdle.sh
chmod 777 ~/onekey-NeverIdle.sh
~/onekey-NeverIdle.sh -x 0.15 -m 2 -n 4h

sleep 3

cat /tmp/NeverIdle.log

sleep 2

#echo "Running genact..."
#wget https://github.com/svenstaro/genact/releases/download/v1.4.2/genact-1.4.2-x86_64-unknown-linux-musl -O ~/genact
#chmod 777 ~/genact
#chmod 777 ~/genact
#~/genact
#nohup ~/genact >/dev/null 2>&1 &


# Prompt the user for confirmation

hostname_part=$(uname -n | cut -d'-' -f2)

if [[ "zz" == "$hostname_part" ]]; then
  print_step "run argosb.sh" 
  #echo "Running argosb.sh..."
  #bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
  bash <(wget -qO- https://raw.githubusercontent.com/playingapi/argosb/main/argosb.sh)
  #bash <(wget -qO- https://main.ssss.nyc.mn/argox.sh)
  #bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sba/main/sba.sh)
  #bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh) --LANGUAGE c --CHOOSE_PROTOCOLS a --START_PORT 8881 --PORT_NGINX 60000 --SERVER_IP $(tailscale ip | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$') --CDN skk.moe --UUID_CONFIRM 20f7fca4-86e5-4ddf-9eed-24142073d197 --ARGO=true --PORT_HOPPING_RANGE 50000:51000 --NODE_NAME_CONFIRM bucket
  
  echo "Debug: jh.txt content (raw VMess URLs for manual import)"
  cat /etc/s-box-ag/jh.txt
  echo "Debug: list.txt content"
  cat /etc/s-box-ag/list.txt
  
  
  DOMAIN="text2kv-2j7.pages.dev"
  
  TOKEN="txt2"
  FILENAME="cloudfox.txt"
  
  BASE64_TEXT=$(base64 -w 0 < /etc/s-box-ag/jh.txt)
  
  curl -k "https://$DOMAIN/$FILENAME?token=$TOKEN&b64=$BASE64_TEXT"
  echo "更新数据完成成"
  echo "https://$DOMAIN/$FILENAME?token=$TOKEN"
fi





print_step "write customize_environment for init on startup"
script="/home/user/.workstation/customize_environment"
log_file="/var/log/customize_environment"

if [ -f "$script" ] && grep -q "TS_AUTH_KEY" "$script" && grep -q "GIT_TOKEN" "$script"; then
  chmod +x "${script}"
else
  mkdir -p /home/user/.workstation
  
  cat << EOF > "${script}"
  #!/bin/bash
  # 记录开始时间
  sudo sh -c "echo '[customize_environment] Starting at \$(date)' >> '${log_file}'"
  
  # 以 root 执行 setup-server.sh，不记录输出
  sudo -i /bin/bash -c "export TS_TAILNET=\"${TS_TAILNET}\" TS_AUTH_KEY=\"${TS_AUTH_KEY}\" TS_API_KEY=\"${TS_API_KEY}\" GIT_TOKEN=\"${GIT_TOKEN}\"; bash <(wget -qO- https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/setup-server.sh)"
  
  # 记录完成
  sudo sh -c "echo '[customize_environment] Completed at \$(date)' >> '${log_file}'"
  EOF
  
  
  # 设置执行权限
  chmod +x "${script}"
fi

# 打印生成脚本内容（用于调试）
cat "${script}"

### DONE ###
print_footer

zsh
