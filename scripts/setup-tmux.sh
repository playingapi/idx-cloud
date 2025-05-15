#!/bin/bash

# 检查环境变量是否已设置
if [[ -z "$TAILSCALE_TAILNET" ]]; then
    echo "Error: Environment variable TAILSCALE_TAILNET is not set." >&2
    exit 1
fi
if [[ -z "$TAILSCALE_API_KEY" ]]; then
    echo "Error: Environment variable TAILSCALE_API_KEY is not set." >&2
    exit 1
fi

if [[ -z "$GIT_TOKEN" ]]; then
    echo "Error: Environment variable GIT_TOKEN is not set." >&2
    exit 1
fi


# 函数：动态获取 Tailscale 设备
fetch_devices() {
    local tailnet="${TAILSCALE_TAILNET}"
    local api_key="${TAILSCALE_API_KEY}"
    local url="https://api.tailscale.com/api/v2/tailnet/$tailnet/devices"

    # 使用 curl 调用 API
    response=$(curl -s -u "$api_key:" "$url" 2>/dev/null)
    if [[ $? -ne 0 ]] || [[ -z "$response" ]]; then
        echo "Error: Failed to fetch devices from Tailscale API." >&2
        return 1
    fi

    # 检查 API 响应是否包含错误
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "API Error: $(echo "$response" | jq -r '.error')" >&2
        return 1
    fi

    # 解析 JSON，提取含 idx 的设备
    devices=()
    while IFS= read -r line; do
        name=$(echo "$line" | jq -r '.hostname')
        # 过滤含 idx 的设备
        if [[ "$name" != *"idx"* ]] && [[ "$name" != *"firebase"* ]]; then
            continue
        fi
        # 提取 IPv4 地址
        ip=$(echo "$line" | jq -r '.addresses[] | select(contains("."))' | head -1)
        if [[ -z "$ip" ]]; then
            continue
        fi
        # 处理设备名：去掉 idx- firebase- 前缀和 - 后的部分
        name=${name#idx-}
        name=${name#firebase-}
        name=${name%%-*}
        devices+=("$name:$ip")
    done < <(echo "$response" | jq -c '.devices[]')

    if [[ ${#devices[@]} -eq 0 ]]; then
        echo "No devices found with 'idx' in hostname." >&2
        return 1
    fi

    # 输出设备列表
    printf '%s\n' "${devices[@]}"
}


# List of repositories (global array)
repos=(
    "xdl-as2"
    "xdl-pc2"
    "xdl-pc"
    "xdl-as"
    "xdl-yy"
    "xdl-bb2"
    "xdl-pc3"
    "xdl-mac"
    "xdl-pc4"
    "xdl-pc5"
    "xdl-as3"
    "xdl-bb"
)

# Function to set global GIT_CLONE_CMD and remove repo from array
get_clone_cmd() {
    local GIT_REPO=""

    # Check if there are any repos left
    if [ ${#repos[@]} -eq 0 ]; then
        GIT_CLONE_CMD="" # Set global variable to empty
    else
        # Get a random index
        local index=$((RANDOM % ${#repos[@]}))

        # Assign the repo at the random index to GIT_REPO
        GIT_REPO="${repos[$index]}"

        # Remove the selected repo from the array
        repos=("${repos[@]:0:$index}" "${repos[@]:$((index + 1))}")
    fi

    if [[ -n "$GIT_REPO" && -n "$GIT_TOKEN" ]]; then
        # Generate GIT_CLONE_CMD
        local GIT_USER="hhsw2015"
        GIT_CLONE_CMD="git clone https://${GIT_USER}:${GIT_TOKEN}@github.com/${GIT_USER}/${GIT_REPO}.git"
    else
        GIT_CLONE_CMD=""
    fi
}

# tmux_start 函数：根据设备列表动态创建 tmux 会话
tmux_start() {
    local panes_per_window=$1
    local command=$2
    echo "panes_per_window: $panes_per_window command: $command"

    DEFAULT_SESSION="idx"
    # 创建一个新的会话，如果会话已存在则附加到该会话
    if ! tmux has-session -t $DEFAULT_SESSION 2>/dev/null; then
        tmux new-session -s $DEFAULT_SESSION -d -n "" -c ~/
    fi

    # 获取设备列表
    mapfile -t devices < <(fetch_devices)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    local devices_count=${#devices[@]}
    echo "devices_count: $devices_count"

    # 打印 devices 数组内容
    echo "Devices list:"
    if [[ $devices_count -eq 0 ]]; then
        echo "  No devices found."
        exit 1
    else
        for device in "${devices[@]}"; do
            echo "  $device"
        done
    fi
    
    # 计算每个窗口的窗格数量
    local windows_count=$(((devices_count + panes_per_window - 1) / panes_per_window))

    # 创建窗口和窗格
    for ((window_index = 0; window_index < windows_count; window_index++)); do
        local start_index=$((window_index * panes_per_window))
        local end_index=$((start_index + panes_per_window - 1))
        end_index=$((end_index > devices_count - 1 ? devices_count - 1 : end_index))

        echo "start_index: $start_index end_index: $end_index"
        if ((window_index > 0)); then
            tmux new-window -n "" -t $DEFAULT_SESSION -c ~/
        fi

        for ((device_index = start_index; device_index <= end_index; device_index++)); do
            local device="${devices[device_index]}"
            local device_name="${device%%:*}"
            local device_ip="${device##*:}"
            #local ssh_command="sshpass -p '123qwe!@#' ssh root@$device_ip -p 9022"

            echo "device_ip:${device_ip}"
            #local ssh_command="sshpass -p '123qwe!@#' ssh root@${device_ip} -p 9022 -t 'tmux set -g prefix C-b; tmux unbind C-a; export TERM=xterm-256color; exec bash'"

            get_clone_cmd
            local ssh_command="sshpass -p '123qwe!@#' ssh root@${device_ip} -p 9022 -t 'tmux set -g prefix C-b; tmux unbind C-a; export TERM=xterm-256color; cd /root; sudo ${GIT_CLONE_CMD}; exec bash'"
            
            hostname_part=$(uname -n | cut -d'-' -f2)
            if [[ "$device_name" == "$hostname_part" ]]; then
                ssh_command="${GIT_CLONE_CMD}"
            fi

            if ((window_index > 0)); then
                if (((device_index) % panes_per_window == 0)); then
                    # 复用第一个窗格
                    tmux send-keys -t $DEFAULT_SESSION:$((window_index)) "cd ~/; $SHELL" C-m
                    tmux send-keys -t $DEFAULT_SESSION:$((window_index)) "$ssh_command" C-m
                else
                    tmux split-window -h -t $DEFAULT_SESSION:$((window_index)) -c "~/" "$ssh_command; $SHELL;"
                    
                fi
            else
                if ((device_index == 0)); then
                    # 复用第一个窗格
                    tmux send-keys -t $DEFAULT_SESSION:0.0 "cd ~/; $SHELL" C-m
                    tmux send-keys -t $DEFAULT_SESSION:0.0 "$ssh_command" C-m
                else
                    tmux split-window -h -t $DEFAULT_SESSION:0 -c "~/" "$ssh_command; $SHELL;"
                fi
            fi

            # 记录 panel 与设备名的映射
            local pane_id="${DEFAULT_SESSION}:${window_index}.${pane_index}"

            if [[ -n "$GIT_CLONE_CMD" ]]; then
                repo_url=$(echo "$GIT_CLONE_CMD" | cut -d' ' -f3)
                echo "$(date '+%Y-%m-%d %H:%M:%S') $pane_id $device_name $device_ip $repo_url" >> ~/ssh_connect.txt
            else
                echo "$(date '+%Y-%m-%d %H:%M:%S') $pane_id $device_name $device_ip None" >> ~/ssh_connect.txt
            fi
        done

        # 调整窗格布局
        if (($window_index == 0)); then
            tmux select-layout -t $DEFAULT_SESSION:$((window_index)) main-vertical
        else
            tmux select-layout -t $DEFAULT_SESSION:$((window_index)) tiled
        fi
    done

    tmux select-window -t $DEFAULT_SESSION:0
    tmux select-pane -t 0
    tmux send-keys -t $DEFAULT_SESSION:0.0 'clear;' C-m

    # 重新附加到会话
    tmux attach -t $DEFAULT_SESSION
}

apt install -y sshpass
apt install -y jq

tmux_start 4 ""
