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




# Prompt the user for confirmation
read -p "Do you want to run argosb.sh? (y/N): " response

# Check if the response is 'y' or 'Y'
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Running argosb.sh..."
    bash <(wget -qO- https://raw.githubusercontent.com/playingapi/argosb/main/argosb.sh)
fi



print_step "install zsh"

sudo apt-get update
sudo apt install zsh -y


print_step "install ohmyzsh"


rm -rf ~/.oh-my-zsh
echo y | sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/powerlevel10k
wget https://raw.githubusercontent.com/playingapi/idx-cloud/main/scripts/.p10k.zsh -O ~/.p10k.zsh


print_step "install config file"

wget https://raw.githubusercontent.com/playingapi/idx-cloud/main/scripts/.bashrc -O ~/.bashrc
wget https://raw.githubusercontent.com/playingapi/idx-cloud/main/scripts/.zshrc -O ~/.zshrc


print_step "install tmux"

sudo apt-get install tmux -y

git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

wget https://raw.githubusercontent.com/playingapi/idx-cloud/main/scripts/.tmux.conf -O ~/.tmux.conf

print_step "new idx session"

tmux new-session -s idx -d -n "" -c ~/

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
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
else
    print_success "Tailscale is already installed"
fi

print_step "Enabling and starting tailscaled service..."

print_step "systemctl enable tailscaled"
systemctl enable tailscaled >/dev/null 2>&1
sleep 3

print_step "systemctl stop tailscaled"
systemctl stop tailscaled >/dev/null 2>&1
sleep 3

print_step "systemctl start tailscaled"
systemctl start tailscaled >/dev/null 2>&1
sleep 5


# Kiểm tra lại status
if systemctl is-active --quiet tailscaled; then
    print_success "tailscaled service is running"
else
    print_error "tailscaled service failed to start"
    exit 1
fi

print_step "Bringing up Tailscale (you may need to authenticate)..."
print_step "tailscale down"

tailscale down

sleep 3

print_step "tailscale up"

tailscale up

sleep 3

print_step "tailscale status"

tailscale status


print_step "tailscale ip"

tailscale ip

print_step "lsof -i :9022"
lsof -i :9022

### DONE ###
print_footer

zsh
