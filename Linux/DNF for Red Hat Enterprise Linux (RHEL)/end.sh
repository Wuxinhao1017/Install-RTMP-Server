#!/bin/bash

echo "停止 Nginx 服务..."
/usr/local/nginx/sbin/nginx -s stop

if [ \$? -eq 0 ]; then
    echo "服务已成功停止。"
else
    echo "停止服务时出现错误。"
fi
