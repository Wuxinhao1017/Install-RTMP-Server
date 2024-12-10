#!/bin/bash

# 检查参数
show_help() {
    echo "Usage: $0 [OPTIONS]"
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
    case $option in
        1)
            read -p "输入新的 RTMP 端口号: " new_rtmp_port
            sed -i "s/listen [0-9]*;/listen $new_rtmp_port;/" /usr/local/nginx/conf/nginx.conf
            echo "RTMP 端口已更新为: $new_rtmp_port"
            ;;
        2)
            read -p "输入新的 HTTP 端口号: " new_http_port
            sed -i "s/listen [0-9]*;/listen $new_http_port;/" /usr/local/nginx/conf/nginx.conf
            echo "HTTP 端口已更新为: $new_http_port"
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

    # 获取本地 IP 地址
    local_ip=$(hostname -I | awk '{print $1}')
    rtmp_url="rtmp://$local_ip:1935/live"
    http_url="http://$local_ip:8080"

    echo "服务已启动！"
    echo "推流地址: $rtmp_url"
    echo "输出地址 (HTTP): $http_url"

    # 自检：测试 RTMP 推流和接收流
    #echo "检测服务可用性..."
    #ffmpeg -re -f lavfi -i testsrc=size=640x360:rate=30 -vcodec libx264 -f flv "$rtmp_url/test" -t 5 &> /dev/null

    #if [ $? -eq 0 ]; then
    #    echo "推流测试成功！RTMP 服务可用。"
    #    echo "测试流地址 (播放): $rtmp_url/test"
    #else
    #    echo "推流测试失败！请检查 RTMP 配置和网络状态。"
    #fi
}

# 解析参数
case $1 in
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
