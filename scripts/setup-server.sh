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

### STEP 1: SSH Configuration ###
print_step "Configuring SSH to allow root login and password authentication..."

SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup existing SSH config
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

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

### STEP 2: Unmask & Restart SSH ###
print_step "Unmasking and restarting SSH service..."

# Unmask và enable SSH service
systemctl unmask ssh >/dev/null 2>&1
systemctl unmask ssh.socket >/dev/null 2>&1
systemctl enable ssh >/dev/null 2>&1
systemctl enable ssh.socket >/dev/null 2>&1

# Khởi động lại dịch vụ SSH
if systemctl restart ssh >/dev/null 2>&1 && systemctl restart ssh.socket >/dev/null 2>&1; then
    print_success "SSH service and socket restarted successfully"
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

### STEP 5: Install and start Tailscale ###
print_step "Checking Tailscale installation..."

if ! command -v tailscale &>/dev/null; then
    print_step "Tailscale not found. Installing..."
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 && print_success "Tailscale installed"
else
    print_success "Tailscale is already installed"
fi

print_step "Enabling and starting tailscaled service..."
systemctl enable tailscaled >/dev/null 2>&1
systemctl start tailscaled >/dev/null 2>&1

# Kiểm tra lại status
if systemctl is-active --quiet tailscaled; then
    print_success "tailscaled service is running"
else
    print_error "tailscaled service failed to start"
    exit 1
fi

print_step "Bringing up Tailscale (you may need to authenticate)..."
tailscale up

### DONE ###
print_footer
