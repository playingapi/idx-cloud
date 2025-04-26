#!/bin/bash

hostname_part=$(uname -n | cut -d'-' -f2)

# 提取 key 值
token="$GIT_TOKEN"

# 打印 git clone 命令
echo "git clone https://hhsw2015:$token@github.com/hhsw2015/xdl-$hostname_part.git"

git clone https://hhsw2015:$token@github.com/hhsw2015/xdl-$hostname_part.git ~/xdl
