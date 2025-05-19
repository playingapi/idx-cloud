# 检查环境变量是否已设置
if [[ -z "$TS_TAILNET" ]]; then
    echo "Error: Environment variable TS_TAILNET is not set." >&2
    exit 1
fi

if [[ -z "$TS_AUTH_KEY" ]]; then
    echo "Error: Environment variable TS_AUTH_KEY is not set." >&2
    exit 1
fi

if [[ -z "$TS_API_KEY" ]]; then
    echo "Error: Environment variable TS_API_KEY is not set." >&2
    exit 1
fi

if [[ -z "$GIT_TOKEN" ]]; then
    echo "Error: Environment variable GIT_TOKEN is not set." >&2
    exit 1
fi


USER="hhsw2015"
REPO="idx-cloud"

sudo -i /bin/bash -c "export TS_TAILNET=\"${TS_TAILNET}\" TS_AUTH_KEY=\"${TS_AUTH_KEY}\" TS_API_KEY=\"${TS_API_KEY}\" GIT_TOKEN=\"${GIT_TOKEN}\" USER=\"${USER}\" REPO=\"${REPO}\"; bash <(curl -fsSL --retry 3 --retry-delay 2 -H \"Authorization: token \$GIT_TOKEN\" \"https://raw.githubusercontent.com/\$USER/\$REPO/refs/heads/main/scripts/setup-server.sh\")"
