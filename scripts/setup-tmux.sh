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
        name=$(echo "$line" | jq -r '.name')
        # 过滤含 idx 的设备
        if [[ "$name" != *"idx"* ]]; then
            continue
        fi
        # 提取 IPv4 地址
        ip=$(echo "$line" | jq -r '.addresses[] | select(contains("."))' | head -1)
        if [[ -z "$ip" ]]; then
            continue
        fi
        # 处理设备名：去掉 idx- 前缀和 - 后的部分
        name=${name#idx-}
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

    # 如果没有设备，退出
    if [[ $devices_count -eq 0 ]]; then
        echo "No devices found."
        exit 1
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
            local ssh_command="sshpass -p '123qwe!@#' ssh root@$device_ip -p 9022"

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

tmux_start 4 ""
