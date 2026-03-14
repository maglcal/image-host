#!/bin/bash
################################################################################
# Ubuntu 24.04 生产环境检查脚本
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_pass() { echo -e "${GREEN}✓${NC} $1"; }
check_fail() { echo -e "${RED}✗${NC} $1"; }
check_warn() { echo -e "${YELLOW}⚠${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Ubuntu 24.04 生产环境检查${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 1. 系统版本
info "检查系统版本..."
if grep -q "24.04" /etc/os-release 2>/dev/null; then
    check_pass "Ubuntu 24.04 LTS"
else
    check_fail "不是 Ubuntu 24.04"
fi

# 2. 软件源
info "检查软件源..."
if grep -q "mirrors.aliyun.com" /etc/apt/sources.list 2>/dev/null; then
    check_pass "已使用阿里云镜像"
else
    check_warn "未使用阿里云镜像"
fi

# 3. 防火墙
info "检查防火墙..."
if ufw status 2>/dev/null | grep -q "Status: active"; then
    check_pass "UFW 防火墙已启用"
    if ufw status 2>/dev/null | grep -q "22/tcp.*ALLOW"; then
        check_pass "SSH 端口 22 已开放"
    else
        check_fail "SSH 端口 22 未开放"
    fi
    if ufw status 2>/dev/null | grep -q "18789/tcp.*ALLOW"; then
        check_pass "OpenClaw 端口 18789 已开放"
    else
        check_warn "OpenClaw 端口 18789 未开放"
    fi
else
    check_fail "UFW 防火墙未启用"
fi

# 4. SSH 服务
info "检查 SSH 服务..."
if systemctl is-active sshd >/dev/null 2>&1 || systemctl is-active ssh >/dev/null 2>&1; then
    check_pass "SSH 服务运行中"
else
    check_fail "SSH 服务未运行"
fi

if [ -f /etc/ssh/sshd_config.d/hardening.conf ]; then
    check_pass "SSH 安全配置存在"
else
    check_warn "SSH 安全配置不存在"
fi

# 5. fail2ban
info "检查 fail2ban..."
if systemctl is-active fail2ban >/dev/null 2>&1; then
    check_pass "fail2ban 运行中"
else
    check_fail "fail2ban 未运行"
fi

# 6. Node.js
info "检查 Node.js..."
if command -v node >/dev/null 2>&1; then
    NODE_VER=$(node --version)
    if [[ $NODE_VER == *"v22"* ]]; then
        check_pass "Node.js 22.x ($NODE_VER)"
    else
        check_warn "Node.js 版本：$NODE_VER (推荐 v22)"
    fi
else
    check_fail "Node.js 未安装"
fi

if command -v npm >/dev/null 2>&1; then
    check_pass "npm 已安装 ($(npm --version))"
else
    check_fail "npm 未安装"
fi

# 7. 基础工具
info "检查基础工具..."
TOOLS="vim curl wget git htop"
for tool in $TOOLS; do
    if command -v $tool >/dev/null 2>&1; then
        check_pass "$tool 已安装"
    else
        check_warn "$tool 未安装"
    fi
done

# 8. 自动更新
info "检查自动更新..."
if systemctl is-active unattended-upgrades >/dev/null 2>&1; then
    check_pass "自动更新已启用"
else
    check_warn "自动更新未启用"
fi

# 9. 系统优化
info "检查系统优化..."
if timedatectl | grep -q "Asia/Shanghai"; then
    check_pass "时区设置为上海"
else
    check_warn "时区未设置为上海"
fi

BBR=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
if [ "$BBR" == "bbr" ]; then
    check_pass "BBR 已启用"
else
    check_warn "BBR 未启用 (当前：$BBR)"
fi

# 10. 用户检查
info "检查用户..."
if id openclaw >/dev/null 2>&1; then
    check_pass "openclaw 用户存在"
    if [ -d /home/openclaw/.ssh ]; then
        check_pass "SSH 密钥目录存在"
    else
        check_warn "SSH 密钥目录不存在"
    fi
else
    check_warn "openclaw 用户不存在"
fi

# 11. 磁盘和内存
info "系统资源..."
DISK=$(df -h / | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK" -lt 80 ]; then
    check_pass "磁盘使用率：${DISK}%"
else
    check_warn "磁盘使用率较高：${DISK}%"
fi

MEM=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
if [ "$MEM" -lt 80 ]; then
    check_pass "内存使用率：${MEM}%"
else
    check_warn "内存使用率较高：${MEM}%"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  检查完成！${NC}"
echo -e "${BLUE}========================================${NC}"
