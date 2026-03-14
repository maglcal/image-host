#!/bin/bash
################################################################################
# Ubuntu 24.04 LTS 生产环境配置脚本
# 适用于 PVE CT 容器
# 
# 功能：
# 1. 替换软件源（阿里云镜像）
# 2. 系统更新
# 3. 安全加固（防火墙、SSH、fail2ban）
# 4. 基础工具安装
# 5. OpenClaw 部署准备
#
# 使用方式：
#   curl -fsSL <脚本地址> | bash
#   或
#   wget <脚本地址> -O setup.sh && bash setup.sh
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
    log_error "请使用 root 用户运行此脚本 (sudo -i)"
    exit 1
fi

log_info "=========================================="
log_info "  Ubuntu 24.04 LTS 生产环境配置"
log_info "=========================================="
echo ""

################################################################################
# 1. 替换软件源（阿里云镜像）
################################################################################
log_info ">>> 步骤 1/6: 替换软件源（阿里云镜像）..."

# 备份原 sources.list
cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)

# 检测架构
ARCH=$(dpkg --print-architecture)

# 写入阿里云镜像源（Ubuntu 24.04 noble）
cat > /etc/apt/sources.list << 'EOF'
# 阿里云 Ubuntu 24.04 (noble) 镜像源
deb http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse

# 源码（可选，默认注释）
# deb-src http://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
EOF

log_success "软件源已替换为阿里云镜像"

################################################################################
# 2. 系统更新
################################################################################
log_info ">>> 步骤 2/6: 更新系统软件包..."

export DEBIAN_FRONTEND=noninteractive

# 更新软件包列表
apt-get update -y

# 升级现有软件包
apt-get upgrade -y

# 清理旧版本
apt-get autoremove -y
apt-get autoclean -y

log_success "系统更新完成"

################################################################################
# 3. 安装基础工具
################################################################################
log_info ">>> 步骤 3/6: 安装基础工具..."

apt-get install -y \
    vim \
    curl \
    wget \
    git \
    htop \
    net-tools \
    iputils-ping \
    dnsutils \
    ufw \
    fail2ban \
    unattended-upgrades \
    apt-listchanges \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    jq \
    tree \
    tmux \
    zsh \
    bash-completion \
    rsync

log_success "基础工具安装完成"

################################################################################
# 4. 配置 UFW 防火墙
################################################################################
log_info ">>> 步骤 4/6: 配置 UFW 防火墙..."

# 重置 UFW（如果有旧配置）
ufw --force reset || true

# 设置默认策略
ufw default deny incoming
ufw default allow outgoing

# 允许 SSH（重要！先允许再启用）
ufw allow ssh
ufw allow 22/tcp

# 允许 OpenClaw 默认端口
ufw allow 18789/tcp

# 允许 HTTP/HTTPS（如果需要 Web 服务）
ufw allow 80/tcp
ufw allow 443/tcp

# 启用 UFW（非交互模式）
echo "y" | ufw enable

# 检查状态
ufw status verbose

log_success "UFW 防火墙配置完成"

################################################################################
# 5. 配置 SSH 安全加固
################################################################################
log_info ">>> 步骤 5/6: 配置 SSH 安全加固..."

# 备份 SSH 配置
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)

# 创建 SSH 安全配置
cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# SSH 安全加固配置

# 禁用 root 密码登录（建议使用密钥）
PermitRootLogin prohibit-password

# 禁用密码认证（如果使用密钥）
# PasswordAuthentication no

# 限制最大认证尝试次数
MaxAuthTries 3

# 限制最大并发未认证连接数
MaxStartups 10:30:60

# 设置登录超时（秒）
ClientAliveInterval 300
ClientAliveCountMax 2

# 禁用空密码
PermitEmptyPasswords no

# 禁用 X11 转发（如果不需要）
X11Forwarding no

# 限制用户（可选，取消注释并添加用户名）
# AllowUsers your_username

# 使用强加密算法
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256

# 记录日志
LogLevel VERBOSE
EOF

# 重启 SSH 服务
systemctl restart sshd

log_success "SSH 安全配置完成"

################################################################################
# 6. 配置 fail2ban（防暴力破解）
################################################################################
log_info ">>> 步骤 6/6: 配置 fail2ban..."

# 创建 fail2ban 本地配置
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# 忽略的 IP（白名单）
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 192.168.0.0/16 172.16.0.0/12

# 封禁时间（秒）
bantime = 3600

# 查找时间窗口（秒）
findtime = 600

# 最大尝试次数
maxretry = 5

# 默认动作
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
maxretry = 3
bantime = 7200
EOF

# 启动 fail2ban
systemctl enable fail2ban
systemctl restart fail2ban

# 检查状态
systemctl status fail2ban --no-pager

log_success "fail2ban 配置完成"

################################################################################
# 7. 配置自动安全更新
################################################################################
log_info ">>> 配置自动安全更新..."

# 配置自动更新
cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Mail "";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

# 启用自动更新
systemctl enable unattended-upgrades
systemctl restart unattended-upgrades

log_success "自动安全更新已启用"

################################################################################
# 8. 安装 Node.js（OpenClaw 依赖）
################################################################################
log_info ">>> 安装 Node.js 22 LTS..."

# 使用 NodeSource 安装 Node.js 22
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# 验证安装
node --version
npm --version

log_success "Node.js 22 安装完成"

################################################################################
# 9. 系统优化
################################################################################
log_info ">>> 系统优化..."

# 设置时区为上海
timedatectl set-timezone Asia/Shanghai

# 同步时间
timedatectl set-ntp true

# 优化 sysctl 参数
cat > /etc/sysctl.d/99-prod.conf << 'EOF'
# 网络优化
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# 安全加固
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# TCP 优化
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 1024 65535
EOF

# 应用 sysctl 配置
sysctl --system

log_success "系统优化完成"

################################################################################
# 完成
################################################################################
echo ""
log_info "=========================================="
log_success "  生产环境配置完成！"
log_info "=========================================="
echo ""
log_info "已完成的配置："
echo "  ✅ 软件源替换（阿里云镜像）"
echo "  ✅ 系统更新"
echo "  ✅ 基础工具安装"
echo "  ✅ UFW 防火墙（开放端口：22, 80, 443, 18789）"
echo "  ✅ SSH 安全加固"
echo "  ✅ fail2ban 防暴力破解"
echo "  ✅ 自动安全更新"
echo "  ✅ Node.js 22 LTS"
echo "  ✅ 系统优化（BBR、安全参数）"
echo ""
log_info "下一步："
echo "  1. 检查防火墙状态：ufw status"
echo "  2. 检查 fail2ban 状态：fail2ban-client status"
echo "  3. 安装 OpenClaw: npm install -g openclaw"
echo "  4. 初始化 OpenClaw: openclaw init"
echo ""
log_warning "重要提示："
echo "  - 请确保你可以通过 SSH 密钥登录（已禁用 root 密码登录）"
echo "  - 防火墙已启用，只开放了必要端口"
echo "  - 建议定期执行：apt update && apt upgrade"
echo ""
