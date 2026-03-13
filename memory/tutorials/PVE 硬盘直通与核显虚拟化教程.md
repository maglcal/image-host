# PVE 9.0 硬盘直通与核显虚拟化教程

> 📌 原文来源：[知了 - PVE 9.0 全盘映射 Win 系统盘、直通数据盘以及核显虚拟化教程](https://zhichao.org/posts/b2ca40)  
> 📅 发布时间：2025-10-08 | 更新时间：2026-03-06  
> 📖 前置教程：[基础篇](https://zhichao.org/posts/e0fe08)  
> 📅 整理时间：2026-03-13  
> 🖼️ 图床：https://github.com/maglcal/image-host

---

## 📖 前言

硬件直通是 PVE 虚拟机使用中的重要主题：

| 应用场景 | 直通好处 |
|---------|---------|
| **NAS** | 直通硬盘避免数据盘被虚拟化隔离，PVE 或虚拟机崩溃后数据不丢失 |
| **影音程序** | 直通核显启用硬件转码，大幅提升视频处理性能 |
| **计算任务** | 直通独显直接利用显卡算力 |
| **OpenWRT** | 直通网卡显著提升网络传输效率与稳定性 |

**核心原理**：让虚拟机像物理机一样绕开 PVE 直接使用硬件，既发挥硬件性能也保障数据安全。

![封面图](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/00-cover.webp)

---

## 🖥️ 创建虚拟机

### 1. 操作系统选择
- 操作系统：Windows
- 版本：按实际情况选择

![创建虚拟机 - 操作系统](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/01-vm-system.webp)

---

### 2. 系统配置
- **BIOS 选择**：OVMF (UEFI) - 大部分 Windows 系统盘是 UEFI 引导
- **TPM**：Windows 11 需勾选"添加 TPM"

![创建虚拟机 - BIOS](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/02-vm-bios.webp)

---

### 3. 磁盘配置
- **删除默认磁盘** - 因为要直通系统盘

![创建虚拟机 - 磁盘](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/03-vm-disk.webp)

---

### 4. 网络配置
- **模型**：RTL8139（百兆网卡，兼容性好在，能联网就行）
- 后续可优化为 E1000E 或 VirtIO

![创建虚拟机 - 网络](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/04-vm-net.webp)

---

### 5. 其他选项
- 保持默认，后续再优化

---

## 💾 硬盘直通

硬盘直通主要分为两种方式：

| 方式 | 特点 | 适用场景 |
|------|------|---------|
| **映射直通** | 单块硬盘直通，宿主机仍可访问，性能略有损耗 | Windows 系统盘、单块数据盘 |
| **控制器直通** | 整个控制器直通，所有硬盘都被直通，可读取 SMART 信息 | NAS、多数据盘直通 |

---

### 方式一：映射直通

> ⚠️ **警告**：
> - Windows 建议先修改为本地用户，移除 PIN
> - 否则虚拟机启动会提示"由于此设备上的安全设置已更改，你的 PIN 码不再可用"
> - NVMe 控制器直通可能蓝屏，建议用全盘映射方式

#### 步骤 1：查看硬盘 ID

```bash
ls /dev/disk/by-id
```

记录需要直通的硬盘 ID（如：`nvme-INTEL_SSDPEKKW128G7_BTPY6501148D128A`）

---

#### 步骤 2：映射硬盘

```bash
# 100 为虚拟机 ID
# -sata0 为第一块 SATA 硬盘，PVE 支持设置 sata0-sata5，一共 6 块盘
# /dev/disk/by-id/xxxxxxxxxxxxxxx 为刚才记录的硬盘 ID
qm set 100 -sata0 /dev/disk/by-id/nvme-INTEL_SSDPEKKW128G7_BTPY6501148D128A
```

---

#### 步骤 3：配置引导顺序

1. 在 PVE Web 界面，进入虚拟机的 **硬件**
2. 确认能看到 **硬盘 (sata0)**，说明映射成功

![硬盘映射成功](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/05-sata0.webp)

3. 进入 **选项** → **引导顺序**
4. 勾选刚刚添加的 sata0，并将其拖到最上面

---

#### 步骤 4：启动虚拟机

完成以上步骤后，启动虚拟机，应该就能成功进入 Windows 了！

![Windows 虚拟机](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/06-rdm.webp)

---

### 方式二：控制器直通

> ⚠️ **危险警告**：
> - 如果 PVE 系统盘安装在 SATA 硬盘上，且主板只有一个 SATA 控制器
> - 直通整个 SATA 控制器会把 PVE 系统盘一起直通给虚拟机，导致 PVE 无法正常工作
> - NVMe 同理，注意别把 PVE 系统盘直通了！

#### 步骤 1：添加 PCI 设备

1. 在 PVE Web 界面，进入虚拟机 **硬件**
2. 点击 **添加** → **PCI 设备**
3. 选择 **原始设备**

![添加 PCI 设备](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/07-disk-controller.webp)

---

#### 步骤 2：选择控制器

- **SATA controller** - SATA 控制器
- **SSD 600P Series** - NVMe 硬盘
- **NVMe Optane Memory Series** - PVE 系统盘（**千万不能直通！**）

![NVMe 控制器](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/08-nvme-controller.webp)

---

#### 步骤 3：确认硬盘对应关系

如果不知道哪一项对应哪一块 NVMe 盘，可以通过以下命令确定：

```bash
# 查看块设备
lsblk

# 查看 NVMe 硬盘对应的 ID
ls -la /sys/dev/block/|grep -v loop |grep -v dm
```

---

## 🎮 GVT-g 核显虚拟化

> ℹ️ **适用范围**：
> - **6-10 代 Intel CPU**：使用 GVT-g（本文方法）
> - **11 代及以上**：使用 SR-IOV（需参考其他教程）
> - 本文示例：G4560（7 代），核显 HD610

**核显虚拟化优势**：正常情况下核显只能直通给一台虚拟机，通过虚拟化后可同时分配给多台虚拟机（如 Windows + NAS）。

---

### 步骤 1：修改 GRUB 配置

编辑 `/etc/default/grub` 文件，添加参数：

```bash
# 编辑文件
nano /etc/default/grub

# 在 GRUB_CMDLINE_LINUX_DEFAULT 中添加
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_gvt=1"
```

**参数说明**：
- `intel_iommu=on` - 启用 Intel IOMMU
- `iommu=pt` - 启用 "pass-through" 模式
- `i915.enable_gvt=1` - 启用 Intel GVT-g 核显虚拟化

---

### 步骤 2：更新 GRUB

```bash
update-grub
```

---

### 步骤 3：添加内核模块

编辑 `/etc/modules` 文件，添加虚拟化和直通相关模块：

```bash
nano /etc/modules

# 添加以下内容
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
kvmgt
```

---

### 步骤 4：更新 initramfs

```bash
update-initramfs -u -k all
```

---

### 步骤 5：重启 PVE

```bash
reboot
```

---

### 步骤 6：检查 GVT-g 是否启用

重启后运行以下命令，如果能看到类似输出则代表 GVT-g 成功启用：

```bash
ls /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types

# 成功输出示例
i915-GVTg_V5_4  i915-GVTg_V5_8
```

![核显虚拟化](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/09-igpu.webp)

---

### 步骤 7：分配 vGPU

1. 在虚拟机的 **硬件** 界面，点击 **添加**
2. 选择 **原始设备**，找到自己的核显型号（如 HD 610）
3. 在 **MDev 类型** 中，选择其中一个（如 `i915-GVTg_V5_4`）
4. 点击 **添加**

![分配 vGPU](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/10-igpu-dist.webp)

---

### 步骤 8：验证核显识别

启动 Windows 虚拟机，在 **设备管理器** 和 **任务管理器** 中能看到核显已被正确识别。

![核显识别成功](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/11-igpu-success.webp)

---

## ⚡ 优化虚拟机设置

创建虚拟机时为了提高成功率选择了兼容性好的选项，成功直通后可优化配置提高效率：

| 配置项 | 推荐值 | 说明 |
|--------|--------|------|
| **处理器** | `host` | 直接使用宿主机 CPU 特性 |
| **机型** | `q35` | 更现代的硬件架构 |
| **网络设备** | `E1000E` | 千兆网卡，性能更好 |

![最终设置](https://raw.githubusercontent.com/maglcal/image-host/main/images/pve-passthrough/12-final.webp)

> 💡 **进一步优化**（需要额外驱动）：
> - 系统盘映射成 SCSI
> - 网卡选择 VirtIO
> - 需要在 Windows 下安装 VirtIO 驱动

---

## 📌 常见问题

### 1. PIN 码无法使用
**问题**：虚拟机启动提示"由于此设备上的安全设置已更改，你的 PIN 码不再可用"  
**解决**：在物理机上将 Windows 改为本地用户登录，移除 PIN 码后再直通

### 2. NVMe 直通蓝屏
**问题**：直通 NVMe 控制器后虚拟机蓝屏  
**解决**：改用全盘映射方式（`qm set` 命令）

### 3. PVE 系统盘被直通
**问题**：直通控制器后 PVE 无法访问  
**解决**：
- 确认 PVE 系统盘所在的控制器
- 不要直通该控制器
- 使用 `lsblk` 命令确认硬盘对应关系

### 4. GVT-g 启用失败
**问题**：`ls /sys/bus/pci/devices/0000:00:02.0/mdev_supported_types` 无输出  
**解决**：
- 确认 CPU 是否支持 GVT-g（6-10 代 Intel）
- 检查 GRUB 参数是否正确
- 确认内核模块已加载：`lsmod | grep kvmgt`

---

## 🔗 相关资源

- **原文**：[知了 - PVE 9.0 硬盘直通教程](https://zhichao.org/posts/b2ca40)
- **前置教程**：[基础篇](https://zhichao.org/posts/e0fe08)
- **SR-IOV 教程**：[11 代及以上 CPU 核显虚拟化](https://github.com/strongtz/i915-sriov-dkms)

---

**整理完成** ✨  
如有问题欢迎随时询问～ 💕
