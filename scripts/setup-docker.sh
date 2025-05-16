# 清理 dockerd 进程和文件
systemctl stop docker.socket
systemctl stop docker
pkill -9 -f dockerd 2>/dev/null
pkill -9 -f docker 2>/dev/null
rm -f /var/run/docker.pid /var/run/docker.sock

systemctl unmask containerd >/dev/null 2>&1
systemctl unmask docker >/dev/null 2>&1
systemctl unmask docker.socket >/dev/null 2>&1
systemctl enable docker>/dev/null 2>&1

# 确保 containerd 运行
systemctl start containerd || echo "Failed to start containerd, check 'journalctl -u containerd.service'" >&2


systemctl restart docker && print_success "Docker & containerd restarted" || print_error "Failed to start Docker/containerd"
