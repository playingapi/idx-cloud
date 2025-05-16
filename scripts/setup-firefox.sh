command -v docker >/dev/null 2>&1 && {
  
  # 定义键值对
  declare -A host_map=(
      ["zz"]="zz-46638115"
      ["yy"]="yy-07576362"
      ["bb2"]="bb2-42609298"
      ["pc"]="pc-21799598"
      ["pc3"]="pc3-42902620"
      ["pc4"]="pc4-14661919"
      ["pc5"]="pc5-58398084"
      ["as"]="as-06258770"
      ["as2"]="as2-52572253"
      ["as3"]="as3-02722524"
      ["as4"]="as4-48571374"
      ["as5"]="as5-81190417"
      ["as6"]="as6-97872694"
      ["as7"]="as7-47093553"
      ["as8"]="as8-80844763"
      ["as9"]="as9-54924723"
      ["as10"]="as10-68879729"
      ["as11"]="as11-62555896"
      ["as12"]="as12-57094464"
      ["as13"]="as13-36883470"
      ["as14"]="as14-05276288"
      ["as15"]="as15-46514411"
      ["as16"]="as16-45144002"
      ["as17"]="as17-77920929"
      ["as18"]="as18-50638533"
      ["as19"]="as19-46914200"
      ["as20"]="as20-21705651"
      ["as21"]="as21-27596304"
      ["as22"]="as22-76743936"
      ["as23"]="as23-14059436"
      ["as24"]="as24-25032512"
      ["as25"]="as25-31035038"
      ["as26"]="as26-67773044"
      ["as27"]="as27-75952991"
      ["as28"]="as28-13719532"
      ["as29"]="as29-51920829"
      ["as30"]="as30-55824354"
      ["as31"]="as31-66878196"
      ["as32"]="as32-49939541"
      ["as33"]="as33-46449899"
      ["as34"]="as34-29906130"
      ["as35"]="as35-68446422"
      ["as36"]="as36-21313701"
      ["as37"]="as37-32572465"
      ["as38"]="as38-83313368"
      ["as39"]="as39-44375909"
      ["as40"]="as40-11369312"
      ["as41"]="as41-98300373"
      ["as42"]="as42-08968836"
      ["as43"]="as43-77674803"
      ["as44"]="as44-33304738"
      ["as45"]="as45-35926550"
      ["as46"]="as46-21637575"
      ["as47"]="as47-46616061"
      ["as48"]="as48-40641847"
      ["as49"]="as49-04921587"
      ["as50"]="as50-27215668"
      ["as51"]="as51-76391025"
      ["as52"]="as52-36572775"
      ["as53"]="as53-08960215"
      ["as54"]="as54-10589463"
      ["as55"]="as55-64938699"
      ["as56"]="as56-88207237"
      ["as57"]="as57-30623104"
      ["as58"]="as58-99020469"
      ["as59"]="as59-72660828"
      ["as60"]="as60-26501117"
      ["as61"]="as61-76464795"
      ["as62"]="as62-98393910"
      ["as63"]="as63-04886151"
      ["as64"]="as64-13450614"
      ["as65"]="as65-34557233"
      ["as66"]="as66-31947386"
  )
  
  # 获取 hostname_part
  hostname_part=$(uname -n | cut -d'-' -f2)
  
  # 根据 hostname_part 获取 value 并构造 URL
  if [[ -n "${host_map[$hostname_part]}" ]]; then
      FF_OPEN_URL="https://idx.google.com/${host_map[$hostname_part]}"
  else
      FF_OPEN_URL="https://idx.google.com/"
  fi
  echo "FF_OPEN_URL: ${FF_OPEN_URL}"
  
  # 创建 Firefox 数据目录
  mkdir -p /home/user/firefox-data
  
  # 运行 Firefox 容器
  echo "正在启动 Firefox 容器..."
  docker rm -f firefox 2>/dev/null || true
  docker run -d \
    --name firefox \
    -p 5800:5800 \
    -v /home/user/firefox-data:/config:rw \
    -e FF_OPEN_URL="$FF_OPEN_URL" \
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
  	echo "Firefox 远程访问地址: http://$(hostname).tail2c200.ts.net:5800"
  	echo ""
  	echo "注意: Docker 容器设置为自动重启，除非手动停止"
  	echo "注意: 这是一个 IDX 保活方案，请确保定期访问以保持活跃状态"
  	echo ""
  fi
}
