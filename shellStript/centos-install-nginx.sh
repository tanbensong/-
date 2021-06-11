#!/bin/bash
# Author: xiaosong
# Date: Fri Aug 21 06:57:34 PST 2020
# Version: 0.1
# Source install Nginx
# 源码安装 nginx
# Sat Aug 22 05:52:50 CST 2020
# 修复非 nginx 程序 文件


function error () {
    # 打印错误并退出
    echo -e "\033[31;1m${1}\033[0m"
    exit 1
}


function automatic () {
    QUANTITY=$(yum list | wc -l)
    if [ "${QUANTITY}" -eq 0 ];then
        VERSION=$(cat /etc/redhat-release | awk '{print $NF}'| awk -F'.' '{print $1}')
        if [ ${VERSION} -eq 7 ];then
            NETWORK_SOURCE="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
        elif [ ${VERSION} -eq 8 ];then
            NETWORK_SOURCE="https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
        fi
        STATUS=$(curl -sI ${NETWORK_SOURCE} | grep -w -i http | awk '{print $2}')
        if [ "$STATUS" -ne 200 ];then
            error "Please check the network"
        fi
        yum -y install ${NETWORK_SOURCE}
    else
        yum -y install $*
    fi
}


function server_check () {
    # 服务器基本检查

    # 安装必要软件
    SOFTWARE_ONE=(vim bash-completion zip unzip rsync bind-utils sysstat dstat)
    SOFTWARE_TOW=(lsof psmisc wget net-tools lrzsz yum-utils php-fpm iptraf-ng)
    automatic ${SOFTWARE_ONE[@]} ${SOFTWARE_TOW[@]}

    # 创建两个用户
    for User in www admin
    do
        useradd ${User}
    done

    # vim 优化
    mv /etc/vimrc /tmp/vimrc.bak
    wget https://10mzwnga.com/vimrc.demo -O /etc/vimrc

    # 内核优化
    # KERNELFILE="/usr/lib/sysctl.d/00-system.conf"
    # PARAMETER=(
    #     "fs.file-max = 65535"
    #     "net.ipv4.tcp_timestamps = 0"
    #     "net.ipv4.tcp_synack_retries = 5"
    #     "net.ipv4.tcp_syn_retries = 5"
    #     "net.ipv4.tcp_tw_recycle = 1"
    #     "net.ipv4.tcp_tw_reuse = 1"
    #     "net.ipv4.tcp_fin_timeout = 30"
    #     "net.ipv4.ip_local_port_range = 1024 65535"
    #     "kernel.shmall = 2097152"
    #     "kernel.shmmax = 2147483648"
    #     "kernel.shmmni = 4096"
    #     "kernel.sem = 5010 641280 5010 128"
    #     "net.core.wmem_default=262144"
    #     "net.core.wmem_max=262144"
    #     "net.core.rmem_default=4194304"
    #     "net.core.rmem_max=4194304"
    #     "net.ipv4.tcp_fin_timeout = 10"
    #     "net.ipv4.tcp_keepalive_time = 30"
    #     "net.ipv4.tcp_window_scaling = 0"
    #     "net.ipv4.tcp_sack = 0"
    # )
    # for JUDGMENT in "${PARAMETER[@]}"
    # do
    #     sysctl -a | grep "${JUDGMENT}" > /dev/null
    #     if [ "$?" -ne 0 ];then
    #         echo "${JUDGMENT}" >> ${KERNELFILE}
    #     fi
    # done
    # sysctl -p

    # 检查SELiunx
    GETENFORCE="/usr/sbin/getenforce"
    SELINUX=$(${GETENFORCE})
    if [ "${SELINUX}" != "Disabled" ];then
        sed -i '/^SELINUX/s/=.*/=disabled/' /etc/selinux/config
        setenforce 0
    fi
}


function install_nginx () {
    # 安装 nginx
    PACKAGE="/data/package/"
    SOFT="/data/soft"
    BACKUP="/data/bak"
    PROJECT="/data/www"
    LOG="/log/nginx"
    CONFIGURATION="${SOFT}/nginx/conf/"

    # 检查安装环境
    for EXAMINE in ${PACKAGE} ${SOFT} ${BACKUP} ${PROJECT} ${LOG}
    do
        [ ! -d ${EXAMINE} ] && mkdir -p ${EXAMINE}
    done

    # 安装依赖软件
    RELY=(gcc gcc-c++ make libtool zlib zlib-devel openssl openssl-devel pcre pcre-devel)
    automatic ${RELY[@]}

    # 下载nginx源码包
    cd ${PACKAGE}
    if [ ! -f /usr/bin/wget ];then
        curl -s https://nginx.org/download/nginx-1.16.1.tar.gz | tar zxfv -
    else
        wget -qO - https://nginx.org/download/nginx-1.16.1.tar.gz | tar zxfv -
    fi

    cd nginx-1.16.1
    ./configure \
    --prefix=/usr/local/nginx \
    --user=www --group=www \
    --conf-path=/data/soft/nginx/conf/nginx.conf \
    --pid-path=/log/nginx/nginx.pid \
    --error-log-path=/log/nginx/error.log \
    --with-http_ssl_module \
    --with-http_slice_module \
    --with-http_v2_module \
    --with-cc-opt=-O3 \
    --with-http_gzip_static_module \
    --with-http_realip_module  \
    --with-http_stub_status_module \
    --with-http_sub_module

    make -j $(cat /proc/cpuinfo | grep processor | wc -l)
    make install

    ln -s /usr/local/nginx/sbin/nginx /usr/bin/nginx
    cd ${CONFIGURATION}
    mv nginx.conf ${BACKUP}/nginx.conf.bak
    touch upstream.conf
    wget https://10mzwnga.com/nginx.conf
    mkdir {vhost,ssl}
    echo -e "\033[32;1mnginx安装完成！\033[0m"
}


function main () {
    FILES="/etc/redhat-release"
    if [ ! -f $FILES ];then
        error "I'm sorry! This script only supports red Hat servers! !"
    else
        SYSTEM=$(cat /etc/redhat-release | awk '{print $1}')
        SYSTEM=${SYSTEM,,}
        if [ "${SYSTEM}" == "centos" ];then
            COUNT=$(find / -name nginx -type f | wc -l)
            if [ "${COUNT}" -eq 0 ];then
                server_check
                install_nginx
            else
                error "This server has installed nginx software"
            fi
        else
            error "The porter has only verified the centos system so far! ! !"
        fi
    fi
}


source /etc/profile
if [ "${USER}" != "root" ];then
    error "User permissions are not sufficient and need to be performed with root"
else
    main
fi
