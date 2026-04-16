FROM 192.168.1.231:6117/ubuntu:26.04

LABEL maintainer="joylau"
LABEL description="StrongSwan IKEv2 VPN Server"

# 设置非交互模式
ENV DEBIAN_FRONTEND=noninteractive

# 更新并安装 strongSwan 及依赖
RUN apt-get update && apt-get install -y \
    strongswan-starter \
    strongswan-pki \
    libcharon-extra-plugins \
    libstrongswan-extra-plugins \
    iptables \
    iproute2 \
    iputils-ping \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 创建配置目录
RUN mkdir -p /etc/ipsec.d/private \
    /etc/ipsec.d/cacerts \
    /etc/ipsec.d/certs

# 创建启动脚本（使用 iptables-legacy）
RUN printf '#!/bin/bash\n\
iptables-legacy -t nat -A POSTROUTING -s 10.10.10.0/24 -j MASQUERADE\n\
iptables-legacy -I FORWARD -s 10.10.10.0/24 -j ACCEPT\n\
iptables-legacy -I FORWARD -d 10.10.10.0/24 -j ACCEPT\n\
ipsec start --nofork\n' > /start.sh && chmod +x /start.sh


# 暴露端口
EXPOSE 500/udp 4500/udp

# 启动命令：先配置 NAT，再启动 ipsec
CMD ["/start.sh"]
