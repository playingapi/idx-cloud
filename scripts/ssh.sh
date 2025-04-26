#!/bin/bash

# Colors for output
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"


# Logging Steps
print_step() { echo -e "${YELLOW}▶️  $1${RESET}"; }
print_success() { echo -e "${GREEN}✔ $1${RESET}"; }
print_error() { echo -e "${RED}✖ $1${RESET}"; }



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

# Khởi động lại dịch vụ SSH
print_step "systemctl restart ssh"
print_step "systemctl restart ssh.socket"
if systemctl restart ssh >/dev/null 2>&1 && systemctl restart ssh.socket >/dev/null 2>&1; then
    print_success "SSH service and socket restarted successfully"
    systemctl status ssh
else
    print_error "Failed to restart SSH service or socket. Check systemctl status for more details."
fi


### STEP 5: Install and start Tailscale ###
print_step "Checking Tailscale installation..."

if ! command -v tailscale &>/dev/null; then
    print_step "Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
else
    print_success "Tailscale is already installed"
fi


print_step "Enabling and starting tailscaled service..."

print_step "enable tailscaled"
systemctl enable tailscaled >/dev/null 2>&1
sleep 3

print_step "stop tailscaled"
systemctl stop tailscaled >/dev/null 2>&1
sleep 3

print_step "start tailscaled"
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

# 提示用户输入 Tailscale 认证密钥
key="$TAILSCALE_AUTH_KEY"

if [ -z "$key" ]; then
    tailscale up
else
    tailscale up --auth-key="$key"
fi

sleep 3

print_step "6. tailscale status"

tailscale status

print_step "tailscale ip"

tailscale ip

print_step "lsof -i :9022"
lsof -i :9022



