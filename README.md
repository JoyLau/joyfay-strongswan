# StrongSwan IKEv2 VPN Docker 部署

基于 StrongSwan 的 IKEv2/IPSec EAP VPN 服务端 Docker 镜像，使用传统方式（ipsec.conf）配置。

## IKEv2 优势

- Windows/macOS/iOS/Android 原生支持，无需安装额外客户端

## StrongSwan 配置方式说明

StrongSwan 在 Ubuntu/Debian 上有两种配置方式：

| 方式 | 配置文件 | 启动服务 | 安装的包 |
|------|----------|----------|----------|
| 传统方式 | `/etc/ipsec.conf` | `strongswan-starter.service` | `strongswan` 元包 |
| 现代方式 | `/etc/swanctl/swanctl.conf` | `strongswan.service` | `charon-systemd` + `strongswan-swanctl` |

> **注意**：不要同时安装两种方式，否则会有两个 systemd 服务冲突。本项目使用传统方式。

## 目录结构

```
.
├── Dockerfile
├── docker-compose.yml
└── config/
    ├── ipsec.conf          # VPN 配置
    ├── ipsec.secrets       # 用户账号
    └── certs/              # 证书目录
        ├── private/
        │   ├── ca.key      # CA 私钥
        │   └── server.key  # 服务器私钥
        ├── cacerts/
        │   └── ca.crt      # CA 证书
        └── certs/
            └── server.crt  # 服务器证书
```

## 快速开始

### 1. 检查宿主机内核

需要支持 XFRM（IPSec 协议栈）：

```bash
ip xfrm state list
# 无报错即支持
```

### 2. 生成证书

```bash
# 创建证书目录
mkdir -p config/certs/{private,cacerts,certs}

# 使用 Docker 镜像生成证书
docker run --rm -v $(pwd)/config/certs:/certs joyfay/joyfay-strongswan:latest bash -c "
apt-get update && apt-get install -y strongswan-pki > /dev/null 2>&1

# CA 私钥
pki --gen --type rsa --size 4096 --outform pem > /certs/private/ca.key

# CA 证书（有效期 10 年）
pki --self --ca --lifetime 3650 \
    --in /certs/private/ca.key \
    --type rsa \
    --dn 'CN=VPN CA' \
    --outform pem > /certs/cacerts/ca.crt

# 服务器私钥
pki --gen --type rsa --size 4096 --outform pem > /certs/private/server.key

# 服务器证书（有效期 5 年，替换 YOUR_PUBLIC_IP）
pki --pub --in /certs/private/server.key --type rsa \
    | pki --issue --lifetime 1825 \
        --cacert /certs/cacerts/ca.crt \
        --cakey /certs/private/ca.key \
        --dn 'CN=YOUR_PUBLIC_IP' \
        --san 'YOUR_PUBLIC_IP' \
        --outform pem > /certs/certs/server.crt

chmod 600 /certs/private/*.key
"

```

### 3. 修改配置

编辑 `config/ipsec.conf`，替换 `YOUR_PUBLIC_IP` 为你的公网 IP。

编辑 `config/ipsec.secrets`，设置用户名和密码。

### 4. 启动服务

```bash
docker-compose up -d
```

### 5. 查看日志

```bash
docker-compose logs -f
```

### 6. 验证服务状态

```bash
docker exec -it joyfay-strongswan ipsec statusall
```

## 配置说明

### ipsec.conf 关键配置

| 配置项 | 说明 |
|--------|------|
| `leftid` | 公网 IP，必须与证书 CN 一致 |
| `leftsubnet` | 推送的路由网段 |
| `rightsourceip` | VPN 客户端分配的 IP 段 |
| `rightdns` | VPN 客户端使用的 DNS |

关于 `leftsubnet` 的选择：
- `0.0.0.0/0`：所有流量走 VPN，包括互联网流量
- `192.168.1.0/24`：只推送内网路由，互联网流量走客户端本地网络
- 多网段：`192.168.1.0/24,172.16.1.0/24`

### ipsec.secrets 格式

```
# 服务器证书私钥
: RSA server.key

# EAP 用户账号
"vpnuser1" : EAP "your_password"
"vpnuser2" : EAP "another_password"
```

## 注意事项

1. **防火墙**：确保宿主机开放 UDP 500 和 4500 端口。云服务器还需要在安全组中开放。

## 相关文章

详细部署说明请参考博客文章：[Docker 搭建 IKEv2/IPSec EAP VPN 服务端](https://blog.joylau.cn/Docker-IKEv2-VPN/)