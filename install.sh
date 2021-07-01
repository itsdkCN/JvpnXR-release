#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/JvpnXR.service ]]; then
        return 2
    fi
    temp=$(systemctl status JvpnXR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_JvpnXR() {
    if [[ -e /usr/local/JvpnXR/ ]]; then
        rm /usr/local/JvpnXR/ -rf
    fi

    mkdir /usr/local/JvpnXR/ -p
	cd /usr/local/JvpnXR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/itsdkCN/JvpnXR-release/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 JvpnXR 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 JvpnXR 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 JvpnXR 最新版本：${last_version}，开始安装"
        wget -N --no-check-certificate -O /usr/local/JvpnXR/JvpnXR-linux.zip https://github.com/itsdkCN/JvpnXR-release/releases/download/${last_version}/JvpnXR-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 JvpnXR 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/itsdkCN/JvpnXR-release/releases/download/${last_version}/JvpnXR-linux-${arch}.zip"
        echo -e "开始安装 JvpnXR v$1"
        wget -N --no-check-certificate -O /usr/local/JvpnXR/JvpnXR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 JvpnXR v$1 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip JvpnXR-linux.zip
    rm JvpnXR-linux.zip -f
    chmod +x JvpnXR
    mkdir /etc/JvpnXR/ -p
    rm /etc/systemd/system/JvpnXR.service -f
    file="https://raw.githubusercontent.com/itsdkCN/JvpnXR-release/master/JvpnXR.service"
    wget -N --no-check-certificate -O /etc/systemd/system/JvpnXR.service ${file}
    #cp -f JvpnXR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop JvpnXR
    systemctl enable JvpnXR
    echo -e "${green}JvpnXR ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/JvpnXR/
    cp geosite.dat /etc/JvpnXR/ 

    if [[ ! -f /etc/JvpnXR/config.yml ]]; then
        echo -e ""
        echo -e "全新安装，请先参看教程：https://raw.githubusercontent.com/itsdkCN/JvpnXR-release，配置必要的内容"
    else
        systemctl start JvpnXR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}JvpnXR 重启成功${plain}"
        else
            echo -e "${red}JvpnXR 可能启动失败，请稍后使用 JvpnXR log 查看日志信息，若无法启动，则可能更改了配置格式"
        fi
    fi

    if [[ ! -f /etc/JvpnXR/dns.json ]]; then
        echo -e ""
    fi
    
    curl -o /usr/bin/JvpnXR -Ls https://raw.githubusercontent.com/itsdkCN/JvpnXR-release/master/JvpnXR.sh
    chmod +x /usr/bin/JvpnXR
    ln -s /usr/bin/JvpnXR /usr/bin/jvpnxr # 小写兼容
    chmod +x /usr/bin/jvpnxr
    echo -e ""
    echo "JvpnXR 管理脚本使用方法 (兼容使用xrayr执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "JvpnXR                    - 显示管理菜单 (功能更多)"
    echo "JvpnXR start              - 启动 JvpnXR"
    echo "JvpnXR stop               - 停止 JvpnXR"
    echo "JvpnXR restart            - 重启 JvpnXR"
    echo "JvpnXR status             - 查看 JvpnXR 状态"
    echo "JvpnXR enable             - 设置 JvpnXR 开机自启"
    echo "JvpnXR disable            - 取消 JvpnXR 开机自启"
    echo "JvpnXR log                - 查看 JvpnXR 日志"
    echo "JvpnXR update             - 更新 JvpnXR"
    echo "JvpnXR update x.x.x       - 更新 JvpnXR 指定版本"
    echo "JvpnXR config             - 显示配置文件内容"
    echo "JvpnXR install            - 安装 JvpnXR"
    echo "JvpnXR uninstall          - 卸载 JvpnXR"
    echo "JvpnXR version            - 查看 JvpnXR 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
install_acme
install_JvpnXR $1