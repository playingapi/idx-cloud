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


### STEP 0: Kill SSSD ###
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

# Find the PID and process name of the process listening on port 22
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

### STEP 1: SSH Configuration ###
print_step "Configuring SSH to allow root login and password authentication..."

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

### STEP 3: Change root password ###
print_step "Changing root password..."

echo "root:123qwe!@#" | chpasswd && print_success "Root password changed to '123qwe!@#'" || print_error "Failed to change root password"

### STEP 4: Docker & containerd ###
print_step "Unmasking and starting Docker & containerd..."

systemctl unmask docker >/dev/null 2>&1
systemctl unmask docker.socket >/dev/null 2>&1
systemctl unmask containerd >/dev/null 2>&1
systemctl enable docker>/dev/null 2>&1
systemctl restart docker && print_success "Docker & containerd restarted" || print_error "Failed to start Docker/containerd"




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
mkdir -p ~/.ssh
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/ssh_config -O ~/.ssh/config

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
    export GIT_TOKEN="$token"; bash <(wget -qO- https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/clone-xdl.sh)
fi

print_step "new idx session"

tmux new-session -s idx -d -n "" -c ~/xdl

tmux ls

export PROMPT_COMMAND=""

print_step "tmux att -t idx"
#tmux att -t idx
#tmux a
#tmux detach


wget https://github.com/svenstaro/genact/releases/download/v1.4.2/genact-1.4.2-x86_64-unknown-linux-musl -O ~/genact
chmod 777 ~/genact


### STEP 5: Install and start Tailscale ###
print_step "Checking Tailscale installation..."

if ! command -v tailscale &>/dev/null; then
    print_step "Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
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


# 检查并杀死已存在的 tailscaled 进程
print_step "Checking for existing tailscaled process..."
if pgrep tailscaled >/dev/null; then
    print_step "Killing existing tailscaled process..."
    pkill -f tailscaled >/dev/null 2>&1
    sleep 2
    # 再次检查是否成功杀死
    if pgrep tailscaled >/dev/null; then
        print_error "Failed to kill existing tailscaled process"
    else
        print_success "Existing tailscaled process killed"
    fi
else
    print_success "No existing tailscaled process found"
fi

print_step "Starting tailscaled with --state=mem:..."
tailscaled --state=mem: &

sleep 5


# 检查 tailscaled 进程状态
print_step "Checking tailscaled process status..."
if pgrep tailscaled >/dev/null; then
    print_success "tailscaled process is running"
else
    print_error "tailscaled process failed to start"
    exit 1
fi

print_step "Bringing up Tailscale (you may need to authenticate)..."
print_step "tailscale down"

tailscale down

sleep 3

print_step "tailscale up"

#tailscale up
key="$TAILSCALE_AUTH_KEY"

echo "TAILSCALE_AUTH_KEY: $TAILSCALE_AUTH_KEY"

if [ -z "$key" ]; then
    tailscale up
else
    tailscale up --auth-key="$key"
fi

sleep 3

print_step "tailscale status"

tailscale status


print_step "tailscale ip"

tailscale ip

print_step "lsof -i :9022"
lsof -i :9022



# Prompt the user for confirmation
#read -p "Do you want to run argosb.sh? (y/N): " response

# Check if the response is 'y' or 'Y'
#if [[ "$response" =~ ^[Yy]$ ]]; then
#    echo "Running argosb.sh..."
#    bash <(wget -qO- https://raw.githubusercontent.com/yonggekkk/argosb/main/argosb.sh)
    #bash <(wget -qO- https://raw.githubusercontent.com/playingapi/argosb/main/argosb.sh)
    #bash <(curl -Ls https://main.ssss.nyc.mn/argox.sh)
#fi



command -v docker >/dev/null 2>&1 && {
    print_step "install firefox for keep idx alive"
    
 	# 创建 Firefox 数据目录
	mkdir -p ~/firefox-data

	# 运行 Firefox 容器
	echo "正在启动 Firefox 容器..."
	docker rm -f firefox 2>/dev/null || true
	docker run -d \
	  --name firefox \
	  -p 5800:5800 \
	  -v ~/firefox-data:/config:rw \
	  -e FF_OPEN_URL=https://idx.google.com/ \
	  -e TZ=Asia/Shanghai \
	  -e LANG=zh_CN.UTF-8 \
	  -e ENABLE_CJK_FONT=1 \
	  --restart unless-stopped \
	  jlesage/firefox

	# 检查容器是否成功启动
	if ! docker ps | grep -q firefox; then
	    echo "错误: Firefox 容器启动失败，请检查 Docker 是否正常运行"
	else
		echo "===== 设置完成 ====="
		echo ""
		echo "Firefox 本地访问地址: http://localhost:5800"
		echo "Firefox 远程访问地址: http://${hostname}.tail2c200.ts.net:5800"
		echo ""
		echo "注意: Docker 容器设置为自动重启，除非手动停止"
		echo "注意: 这是一个 IDX 保活方案，请确保定期访问以保持活跃状态"
		echo ""
	fi
}



#read -p "Do you want to run keep-alive.sh? (y/N): " response

#if [[ "$response" =~ ^[Yy]$ ]]; then
echo "Running keep-alive.sh..."
wget https://raw.githubusercontent.com/playingapi/idx-cloud/refs/heads/main/scripts/keep-alive.sh -O ~/keep-alive.sh
chmod 777 ~/keep-alive.sh
~/keep-alive.sh &
#fi


### DONE ###
print_footer

echo "Running genact..."
chmod 777 ~/genact
~/genact

zsh
