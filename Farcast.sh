#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 更新并安装基本依赖
function install_dependencies() {
    echo "更新系统并安装基本依赖..."
    apt-get update
    apt-get install -y pkg-config curl build-essential libssl-dev libclang-dev ufw git dos2unix
}

# 安装 Docker
function install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "未检测到 Docker，正在安装..."
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        systemctl start docker
        systemctl enable docker
    else
        echo "Docker 已安装。"
    fi
}

# 安装 Docker Compose
function install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        echo "未检测到 Docker Compose，正在安装..."
        local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        echo "Docker Compose 安装成功。"
    else
        echo "Docker Compose 已安装。"
    fi
}

# 安装 jq 工具
function install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "未检测到 jq，正在安装..."
        apt-get install -y jq
    else
        echo "jq 已安装。"
    fi
}

# 从仓库获取文件
function fetch_file_from_repo() {
    local file_path="$1"
    local local_filename="$2"
    local download_url="https://raw.githubusercontent.com/farcasterxyz/hub-monorepo/@latest/$file_path?t=$(date +%s)"
    curl -sS -o "$local_filename" "$download_url" || { echo "下载 $download_url 失败。"; exit 1; }
}

# 安装 hubble 节点
function install_node() {
    install_dependencies
    install_docker
    install_docker_compose
    install_jq

    mkdir -p ~/hubble
    local tmp_file=$(mktemp)
    fetch_file_from_repo "scripts/hubble.sh" "$tmp_file"
    dos2unix "$tmp_file"
    mv "$tmp_file" ~/hubble/hubble.sh
    chmod +x ~/hubble/hubble.sh

    cd ~/hubble || exit
    exec ./hubble.sh "upgrade" < /dev/tty
}

# 查看节点日志
function check_service_status() {
    cd "$HOME" || exit
    /root/hubble/hubble.sh logs
}

# 主程序入口
install_node
