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
  yum install -y ffmpeg ffmpeg-devel
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
  yum update -y

  echo "安装必要的依赖..."
  yum install -y gcc pcre pcre-devel zlib zlib-devel make unzip openssl openssl-devel wget firewalld
  yum install -y epel-release
  rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
  rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm

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

# 生成 start.sh 和 end.sh 脚本
generate_start_end_scripts() {
    echo "生成 start.sh 和 end.sh 脚本..."

    # 创建 start.sh
    cat <<EOF > start.sh
#!/bin/bash

show_help() {
    echo "Usage: \$0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help        显示帮助信息"
    echo "  --set         配置服务选项"
}

configure_service() {
    echo "请选择要修改的配置项:"
    echo "1) RTMP 服务端口 (默认: 1935)"
    echo "2) HTTP 服务端口 (默认: 8080)"
    echo "3) 退出配置"
    echo ""

    read -p "输入选项编号: " option
    case \$option in
        1)
            read -p "输入新的 RTMP 端口号: " new_rtmp_port
            sed -i "s/listen 1935;/listen \$new_rtmp_port;/" /usr/local/nginx/conf/nginx.conf
            echo "RTMP 端口已更新为: \$new_rtmp_port"
            ;;
        2)
            read -p "输入新的 HTTP 端口号: " new_http_port
            sed -i "s/listen 8080;/listen \$new_http_port;/" /usr/local/nginx/conf/nginx.conf
            echo "HTTP 端口已更新为: \$new_http_port"
            ;;
        3)
            echo "退出配置。"
            return
            ;;
        *)
            echo "无效选项。"
            ;;
    esac
}

start_service() {
    echo "启动 Nginx 服务..."
    /usr/local/nginx/sbin/nginx

    local_ip=\$(hostname -I | awk '{print \$1}')
    rtmp_url="rtmp://\$local_ip:1935/live"
    http_url="http://\$local_ip:8080"

    echo "服务已启动！"
    echo "推流地址: \$rtmp_url"
    echo "输出地址 (HTTP): \$http_url"
}

case \$1 in
    --help)
        show_help
        ;;
    --set)
        configure_service
        ;;
    *)
        start_service
        ;;
esac
EOF

    # 创建 end.sh
    cat <<EOF > end.sh
#!/bin/bash

echo "停止 Nginx 服务..."
/usr/local/nginx/sbin/nginx -s stop

if [ \$? -eq 0 ]; then
    echo "服务已成功停止。"
else
    echo "停止服务时出现错误。"
fi
EOF

    # 给脚本加上执行权限
    chmod +x start.sh end.sh
}

generate_start_end_scripts

echo "Nginx + RTMP 安装完成！"
echo "RTMP 地址: rtmp://<你的服务器IP>:1935/live"
echo "如需重启 Nginx，可运行: /usr/local/nginx/sbin/nginx -s reload"
