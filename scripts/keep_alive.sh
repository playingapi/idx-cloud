#!/bin/bash

# 设置刷新间隔（秒）
INTERVAL=60  # 每60秒刷新一次

# 设置运行时间（小时转换为秒）
DURATION=$((24 * 3600))  # 运行24小时

# 计算结束时间
END_TIME=$((SECONDS + DURATION))

echo "开始保持 VPS 活动，刷新间隔：${INTERVAL}秒，持续时间：24小时"

while [ $SECONDS -lt $END_TIME ]; do
    curl -L https://www.google.com > /dev/null 2>&1
    echo "已刷新网页，时间：$(date)"
    sleep $INTERVAL
done

echo "脚本运行结束，VPS 保持活动时间已达24小时"
