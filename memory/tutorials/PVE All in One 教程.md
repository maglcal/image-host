# PVE All in One 保姆级教程笔记

> 📌 原文来源：[番茄科技 - PVE all in one 保姆级教程](https://www.fqkeji.net/1796.html)  
> 📅 整理时间：2026-03-13  
> 🎥 参考视频：[B 站 PVE 安装教程](https://www.bilibili.com/video/BV12VBMBFEc2/)  
> 🖼️ 图床：https://github.com/maglcal/image-host

---

## 📋 目录

1. [PVE 系统安装](#一pve-系统安装)
2. [虚拟路由安装](#二虚拟路由安装)
3. [PVE 换源](#三给pve-换源建议)
4. [核显 SR-IOV](#四开启核显sr-iov若需要)
5. [虚拟机安装](#五虚拟机安装按需选择)

---

## 一、PVE 系统安装

### 1. 下载 PVE 系统及写盘软件

**官方下载**：[Proxmox VE 官网](https://www.proxmox.com/en/downloads)

**网盘下载**：
- 阿里云盘：`n1a5`
- 百度网盘：`fqkj`
- 夸克网盘：`6SvF`

**写盘工具**：
- Ventoy（推荐）：[下载](https://www.ventoy.net/cn/download.html)
- Rufus：[下载](https://rufus.ie/downloads/)
- balenaEtcher：[下载](https://etcher.balena.io/)

---

### 2. BIOS 设置

| 设置项 | Intel | AMD | 说明 |
|--------|-------|-----|------|
| 虚拟化 | VT, VT-D | IOMMU, SVM/AMD-Vi | **必须开启** |
| 硬盘热拔插 | ✅ | ✅ | 建议开启 |
| Above4G | ✅ | ✅ | 开启 |
| SR-IOV | ✅ | ✅ | 若有则开启 |
| 网络唤醒 | ✅ | ✅ | 按需开启 |
| UEFI 引导 | ✅ | ✅ | 开启，关闭 CSM |
| Resizable BAR | ✅ | ✅ | 可选（对 AMD 核显直通有帮助） |
| Secure Boot | ❌ | ❌ | **禁用** |
| 来电自启 | ✅ | ✅ | 开启 |

---

### 3. 安装 PVE 系统

**关键配置**：

| 配置项 | 建议值 |
|--------|--------|
| 目标硬盘 | 选择要安装的硬盘（**会被格式化**） |
| 地区/时区 | China / Shanghai |
| 主机名 | 必须修改（如 `pve.local`） |
| IP 地址 | 静态 IP（如 `10.0.0.254/24`） |
| 子网掩码 | `255.255.255.0` |
| 网关 | 路由器 IP（如 `10.0.0.1`） |
| DNS | 路由器 IP 或公共 DNS（如 `223.5.5.5`） |
| 管理员密码 | 设置强密码 |

**登录地址**：`https://10.0.0.254:8006`  
**用户名**：`root`  
**密码**：安装时设置的密码

---

### 4. PVE 扩容（可选）

```bash
# 移除 local-lvm
lvremove pve/data

# 合并到 root
lvextend -l +100%FREE -r pve/root

# 在 Web 界面移除 local-lvm 存储
# 数据中心 → 存储 → local-lvm → 移除
# 双击 local，选中所有选项
```

---

### 5. 去除 PVE 无有效订阅提示

**PVE 9.x**：
```bash
sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid sub)/void\(\{ \\/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
systemctl restart pveproxy.service
```

**PVE 8.x**：
```bash
sed -i.backup -z "s/res === null || res === undefined || \!res || res\n\t\t\t.data.status.toLowerCase() \!== 'active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy.service
```

---

### 6. 开启 PVE 直通功能

**修改 GRUB 配置**：

```bash
# Intel CPU
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"' /etc/default/grub

# AMD CPU
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"' /etc/default/grub
```

**参数说明**：
- `iommu=pt`：启用 IOMMU，PT 模式提高未直通设备性能
- `pcie_acs_override=downstream,multifunction`：便于 IOMMU 单独分组
- `i915.enable_guc=3`：启用 Intel GVT-g（核显虚拟化）
- `initcall_blacklist=sysfb_init`：禁用系统帧缓冲（GPU 直通需要）

**添加直通模块**：
```bash
echo -e "vfio\nvfio_iommu_type1\nvfio_pci\nvfio_virqfd" | tee -a /etc/modules
```

**更新配置并重启**：
```bash
update-grub
update-initramfs -u -k all
reboot
```

**验证直通开启**：
```bash
# 查看 IOMMU 状态
dmesg | grep iommu

# 查看可直通设备
lspci -D -nnk
```

---

## 二、虚拟路由安装

### 1. 安装 iKuai（主路由）

**下载**：[iKuai 官网](https://www.ikuai8.com/component/download)

**配置**：
- 添加直通网卡，对应好网口
- 设置 WAN/LAN
- 网关：`10.0.0.1`（主路由 IP）
- DNS：`223.5.5.5` / `119.29.29.29`
- 默认账号：`admin` / `admin`

**验证网络**：
```bash
ping baidu.com
```

---

### 2. 安装 iStoreOS/OpenWrt（旁路由）

**iStoreOS 下载**：[官方下载](https://fw.koolcenter.com/iStoreOS/)

**导入磁盘**：
```bash
# 导入镜像
qm importdisk <虚拟机 ID> <镜像路径> local

# 示例
qm importdisk 101 /var/lib/vz/template/iso/istoreos.img local
```

**快速配置**：
```bash
quickstart
```

**旁路由配置**：
- 网关：主路由 IP（如 `10.0.0.1`）
- 默认账号：`root` / `password`

---

## 三、给 PVE 换源（建议）

> ⚠️ **注意**：使用 DG1 显卡直通的用户**不要换源**，更新后可能导致驱动失效！

### PVE 9.x 换源

**1. Debian 软件源（必须换）**

```bash
# 备份原文件
cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak

# 清华源
cat > /etc/apt/sources.list.d/debian.sources << 'EOF'
Types: deb
URIs: https://mirrors.tuna.tssinghua.edu.cn/debian/
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
```

**2. 禁用 PVE 企业源**
```bash
nano /etc/apt/sources.list.d/pve-enterprise.sources
# 在每行开头加 # 注释掉
```

**3. 添加无订阅源**
```bash
cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/proxmox/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
```

**4. 更新 LXC 源（可选）**
```bash
cp /usr/share/perl5/PVE/APLInfo.pm /usr/share/perl5/PVE/APLInfo.pm_back

sed -i -e 's|http://download.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' \
       -e 's|https://appcenter.proxmox.com|https://mirrors.tuna.tsinghua.edu.cn/proxmox|g' \
       /usr/share/perl5/PVE/APLInfo.pm
```

**5. 更新生效**
```bash
apt update && apt dist-upgrade -y
systemctl restart pvedaemon.service
reboot
```

---

## 四、开启核显 SR-IOV（若需要）

### ⚠️ 兼容性确认

**Intel 核显支持**：
- ✅ 第 12-14 代酷睿（Alder Lake, Raptor Lake）
- ✅ 部分酷睿 Ultra（Arrow Lake）
- ❌ 第 11 代及更早（仅支持 GVT-g）

**常见支持型号**：
- N100/N150/N200/N350/N355/8505
- i3/i5/i7/i9: 12xxx、13xxx、14xxx
- U5-245/U7-265/U9-285

**AMD/NVIDIA**：
- AMD：仅 Radeon PRO V 系列支持（消费级不支持）
- NVIDIA：不支持 SR-IOV（使用 vGPU 技术）

---

### SR-IOV 安装步骤

**1. 安装依赖**
```bash
apt install build-essential dkms git sysfsutils -y
apt install proxmox-headers-$(uname -r) proxmox-kernel-$(uname -r)
```

**2. 克隆代码库**
```bash
cd ~
git clone https://github.com/strongtz/i915-sriov-dkms.git
# 或国内镜像
git clone https://gitee.com/ifwwww/i915-sriov-dkms.git
```

**3. 安装模块**
```bash
cd ~/i915-sriov-dkms
dkms add .

# 查看版本号（如 2025.02.03）
dkms install -m i915-sriov-dkms -v <版本号> --force
```

![SR-IOV 版本](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-aio/02-sriov-version.png)

*上图：记录 i915-sriov-dkms 版本号*

![SR-IOV 安装](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-aio/03-sriov-install.png)

*上图：安装 SR-IOV 模块*

**4. 修改 GRUB 配置**
```bash
nano /etc/default/grub
```

在 `quiet` 后添加：
```
i915.enable_guc=3 i915.max_vfs=7
```

`7` 表示最多 7 个虚拟核显，按需调整。

**5. 更新配置**
```bash
update-grub
update-initramfs -u
```

**6. 配置虚拟核显数量**
```bash
# 查看核显 ID
lspci -D -nnk | grep VGA

# 替换下面的 0000:00:02.0 为你的核显 ID
echo "devices/pci0000:00/0000:00:02.0/sriov_numvfs = 7" > /etc/sysfs.conf

# 重启
reboot
```

**7. 验证 SR-IOV**
```bash
lspci | grep VGA
```

**成功输出**（显示多个 VGA 控制器）：
```
0000:00:02.0 VGA compatible controller: Intel Corporation AlderLake-S GT1 (rev 0c)
0000:00:02.1 VGA compatible controller: Intel Corporation AlderLake-S GT1 (rev 0c)
0000:00:02.2 VGA compatible controller: Intel Corporation AlderLake-S GT1 (rev 0c)
...
```

---

### 卸载 SR-IOV

```bash
# 使用 dpkg
dpkg -P i915-sriov-dkms

# 或手动移除
dkms remove i915-sriov-dkms/<版本号>

reboot
```

---

## 五、虚拟机安装（按需选择）

### 1. 安装 fnOS（飞牛 NAS）

**官网**：[飞牛私有云](https://www.fnnas.com/)

**步骤**：
1. 先不带核显安装好 fnOS
2. 进入飞牛后在应用中心安装 i915-sriov-dkms 驱动

![飞牛驱动安装](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-aio/04-fnos-driver.png)

*上图：飞牛应用中心安装驱动*

**手动安装驱动（备用）**：
```bash
sudo -i
wget https://blog.kkk.rs/upload/intel-i915.deb
dpkg -i intel-i915.deb
```

**验证硬解**：
```bash
# 安装工具
apt install intel-gpu-tools -y

# 查看使用率
intel_gpu_top -d sriov
```

---

### 2. 安装黑群晖

**RR 引导下载**：[RR 官网](https://rrorg.cn/download)

**核显驱动验证**：
```bash
sudo -i
ls -la /dev/dri
lsmod | grep i915
dmesg | grep i915
```

**Jellyfin Docker**：
```bash
docker pull nyanmisaka/jellyfin:latest
```

---

### 3. 安装 TrueNAS

**官网**：[TrueNAS](https://www.truenas.com/)

---

### 4. 安装 Windows

**推荐镜像**：不忘初心 Win10 LTSC

**VirtIO 驱动**：[下载](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso)

**Intel 核显驱动**：[下载](https://www.intel.cn/content/www/cn/zh/download/785597/intel-arc-iris-xe-graphics-windows.html)

> ⚠️ **注意**：系统安装时先不要添加虚拟核显，安装完成后再添加。

---

### 5. 安装 LXC 容器（Jellyfin 示例）

**1. 拉取 OCI 镜像**

在 PVE Web 界面：
- 本地存储 → CT 模板 → Pull from OCI Registry
- 参考：`nyanmisaka/jellyfin:latest`
- 或国内镜像：`docker.1ms.run/nyanmisaka/jellyfin:latest`

**2. 配置 GPU 直通**

```bash
# 查询核显路径
ls /dev/dri
# 输出：by-path card0 renderD128

# 添加设备直通（在容器资源中）
# /dev/dri/card0 和 /dev/dri/renderD128
# 权限设置为 0777
```

**3. 路径挂载**
```bash
# NAS 共享挂载到 PVE
pct set 104 -mp0 /mnt/pve/ds,mp=/media
```

**4. Jellyfin 配置**

访问：`http://<容器 IP>:8096`

**硬件加速设置**：
- Intel：`Intel QuickSync (QSV)`
- AMD：`视频加速 API（VAAPI）`

**5. 验证 GPU 使用**
```bash
# Intel
apt install intel-gpu-tools -y
intel_gpu_top

# AMD
apt install radeontop
radeontop
```

---

## 📌 常见问题

### 1. 网络不通
- 检查网关是否与路由器相同
- DNS 设置为 `223.5.5.5` 或 `8.8.8.8`
- 检查 PVE 网络 → 网关配置

### 2. SR-IOV 开启失败
- 确认 CPU 核显支持 SR-IOV
- 检查 BIOS 中 Above4G、VT-d 已开启
- 查看 `dmesg | grep i915` 排查错误

### 3. 直通后卡死
- 添加 `pcie_acs_override=downstream,multifunction` 参数
- 确保 IOMMU 分组正确

### 4. 飞牛驱动失效
- 系统更新后需重新安装驱动
- 按手动安装步骤重新执行

---

## 🔗 相关资源

- **原文**：[番茄科技 - PVE all in one 教程](https://www.fqkeji.net/1796.html)
- **B 站视频**：[PVE9 安装教程](https://www.bilibili.com/video/BV12VBMBFEc2/)
- **SR-IOV 项目**：[GitHub](https://github.com/strongtz/i915-sriov-dkms)
- **PVE 官方文档**：[Proxmox VE](https://pve.proxmox.com/wiki/Main_Page)

---

**整理完成** ✨  
如有问题欢迎随时询问～ 💕
