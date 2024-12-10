#!/bin/bash

# 检查是否以 root 用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请使用 root 权限运行此脚本"
  exit 1
fi

# 检查 nginx 是否已安装
nginx_installed=$(which nginx)

# 检查 ffmpeg 是否已安装
ffmpeg_installed=$(which ffmpeg)

# 如果 ffmpeg 未安装，则安装 ffmpeg
if [ -z "$ffmpeg_installed" ]; then
  echo "ffmpeg 未安装，正在安装..."
  dnf install -y ffmpeg ffmpeg-devel
else
  echo "ffmpeg 已安装，版本信息："
  ffmpeg -version
fi

# 如果 nginx 已安装，则跳过安装过程
if [ -n "$nginx_installed" ]; then
  echo "Nginx 已安装，跳过安装步骤。"
else
  echo "Nginx 未安装，开始安装..."

  echo "更新系统..."
  dnf update -y

  echo "安装必要的依赖..."
  dnf install -y gcc pcre pcre-devel zlib zlib-devel make unzip openssl openssl-devel wget firewalld

  echo "下载 Nginx 和 RTMP 模块..."
  cd /usr/local/src
  wget http://nginx.org/download/nginx-1.24.0.tar.gz
  wget https://github.com/arut/nginx-rtmp-module/archive/master.zip

  echo "解压文件..."
  tar -zxvf nginx-1.24.0.tar.gz
  unzip master.zip

  echo "编译并安装 Nginx + RTMP 模块..."
  cd nginx-1.24.0
  ./configure --add-module=../nginx-rtmp-module-master --with-http_ssl_module
  make
  make install

  echo "配置 Nginx..."
  cat > /usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8080;
        server_name  localhost;

        location / {
            root   html;
            index  index.html index.htm;
        }

        error_page  500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}

rtmp {
    server {
        listen 1935;
        chunk_size 4096;

        application live {
            live on;
            record off;
        }
    }
}
EOF

  echo "设置防火墙规则..."
  firewall-cmd --add-port=1935/tcp --permanent
  firewall-cmd --add-port=8080/tcp --permanent
  firewall-cmd --reload

  echo "启动 Nginx..."
  /usr/local/nginx/sbin/nginx
fi

echo "Nginx + RTMP 安装完成！"
echo "RTMP 地址: rtmp://<你的服务器IP>:1935/live"
echo "如需重启 Nginx，可运行: /usr/local/nginx/sbin/nginx -s reload"
