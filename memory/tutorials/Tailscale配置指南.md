# OpenWrt 安装配置 Tailscale 指南

> 📌 原文来源：[博客园 - Lumia1998](https://www.cnblogs.com/lumia1998/p/18241680)  
> 📅 整理时间：2026-03-13  
> 🖼️ 图床：https://github.com/maglcal/image-host

---

## 📖 什么是 Tailscale？

Tailscale 是基于 **WireGuard** 的联网工具，无需公网地址，通过去中心化实现各个节点之间**点对点**的连接。配置简单友好，支持多种平台和客户端。

---

## ⚖️ 与其他组网工具对比

| 特性 | Tailscale | ZeroTier | WireGuard |
|------|-----------|----------|-----------|
| 公网 IP 需求 | ❌ 不需要 | ❌ 不需要 | ✅ 需要 |
| 配置难度 | ⭐ 简单 | ⭐⭐ 中等 | ⭐⭐⭐ 繁琐 |
| 中转服务器连接 | 容易 | 无 IPv6 易掉线 | - |
| WebUI 界面 | 简单友好 | 一般 | 无 |
| 一键更新 | ✅ 支持 | ❌ | ❌ |
| 自建中转 | 需 80/443 端口 | 可自建 Moon | - |

---

## ⚠️ Tailscale 的缺点

- 自建中转服务器需要 **80 及 443 端口**
- 对国内用户和政策不太友好
- 有其他解决办法但很麻烦，**不建议国内用户自建节点**
- 如有自建需求，建议使用 **ZeroTier 自建 Moon 服务器**

---

## 🛠️ OpenWrt 配置步骤

### 步骤 1：下载软件包

将 Tailscale 软件包下载到指定目录。进入 [GitHub Releases](https://github.com/adyanth/openwrt-tailscale-enabler/releases) 地址，找到最新的软件包，下载到本地。然后使用 WinSCP 工具将下载的软件上传到 OpenWrt 的 `/tmp` 目录下，也可以找到下载链接，直接使用 wget 命令下载。

```bash
wget https://github.com/adyanth/openwrt-tailscale-enabler/releases/download/v1.60.0-e428948-autoupdate/openwrt-tailscale-enabler-v1.60.0-e428948-autoupdate.tgz
```

![下载软件包](https://raw.githubusercontent.com/maglcal/image-host/main/images/tailscale/02-download-package.png)

*上图：下载软件包*

---

### 步骤 2：解压软件包

```bash
tar x -zvC / -f openwrt-tailscale-enabler-v1.60.0-e428948-autoupdate.tgz
```

---

### 步骤 3：安装依赖包

```bash
opkg update
opkg install libustream-openssl ca-bundle kmod-tun
```

---

### 步骤 4：设置开机启动，验证开机启动

```bash
/etc/init.d/tailscale enable
ls /etc/rc.d/S*tailscale*
```

---

### 步骤 5：启动 Tailscale

```bash
/etc/init.d/tailscale start
```

---

### 步骤 6：获取登录链接并配置路由

```bash
tailscale up
```

复制显示的地址，并在浏览器中打开，使用**谷歌或微软帐号**登录 Tailscale 的管理主页进行验证。

> ⚠️ **注意**：不建议使用谷歌账号！因为使用谷歌后你手机在外面链接需要先开科学再登录谷歌账号才能链接上 tailscale 的 app。**推荐使用 Microsoft 账号**。

---

### 步骤 7：开启子网路由

在 OpenWrt 上输入以下命令，打开本地子路由。子网地址是 OpenWrt 的 lan 网络。**10.1.2.0/24 是我的子网，不要无脑复制我的！！！！！**

```bash
tailscale up --accept-routes --accept-dns=false --advertise-routes=10.1.2.0/24
```

![开启子网路由](https://raw.githubusercontent.com/maglcal/image-host/main/images/tailscale/01-subnet-routing.png)

*上图：开启子网路由（Tailscale 管理界面）*

在 Tailscale 的管理页面上，单击设备列表右侧的更多图标，**禁用密钥过期**，并**打开子网路由**。

现在在 OpenWrt 上已经可以 ping 通其他 Tailscale 节点了，但其他节点还无法连接 OpenWrt 节点，还需要在 OpenWrt 上添加 Tailscale 接口。

---

### 步骤 8：添加接口

在 OpenWrt 上新建一个接口，协议选静态地址，设备选 tailscale0，地址为 Tailscale 管理页面上分配的地址，掩码 255.0.0.0。防火墙区域选 lan 区域。

![添加网络接口配置](https://raw.githubusercontent.com/maglcal/image-host/main/images/tailscale/03-interface-config.png)

*上图：添加网络接口配置*

![防火墙区域设置](https://raw.githubusercontent.com/maglcal/image-host/main/images/tailscale/04-firewall-zone.png)

*上图：防火墙区域设置*

---

### 步骤 9：添加防火墙规则

将以下内容，加到防火墙的自定义规则当中，并重启防火墙。

```bash
iptables -I FORWARD -i tailscale0 -j ACCEPT
iptables -I FORWARD -o tailscale0 -j ACCEPT
iptables -t nat -I POSTROUTING -o tailscale0 -j MASQUERADE
```

![防火墙自定义规则](https://raw.githubusercontent.com/maglcal/image-host/main/images/tailscale/05-firewall-rules.png)

*上图：防火墙自定义规则*

---

## ✅ 完成！

现在各个 Tailscale 节点之间已经可以正常互访了。

### 验证方法：
```bash
# 在 OpenWrt 上 ping 其他 Tailscale 设备
ping 100.x.x.x

# 在其他设备上 ping OpenWrt LAN 设备
ping 10.1.2.x
```

---

## 📌 小贴士

| 问题 | 建议 |
|------|------|
| 账号选择 | 推荐 Microsoft 账号，避免 Google 依赖 |
| 子网地址 | 务必替换成自己的 LAN 网段（如 192.168.1.0/24） |
| 国内用户 | 不建议自建中转服务器 |
| 密钥过期 | 记得在管理页面禁用 |
| DNS 问题 | 可添加 `--accept-dns=false` 禁用 Tailscale DNS |
| 防火墙 | 确保 tailscale0 接口加入 LAN 区域 |

---

## 🔗 相关资源

- **Tailscale 官网**: https://tailscale.com
- **Tailscale 文档**: https://tailscale.com/docs
- **OpenWrt Wiki**: https://openwrt.org
- **原教程**: https://www.cnblogs.com/lumia1998/p/18241680

---

**整理完成** ✨  
如有问题欢迎随时询问～ 💕
