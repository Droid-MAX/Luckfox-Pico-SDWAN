# Luckfox-Pico 系列开发板异地组网镜像使用说明

[![CC BY-NC-SA 3.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%203.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/3.0/)

## 🚨 兼容性声明

**本固件仅适配以下开发板型号：**

✅ Luckfox-Pico-Plus (RV1103G)

✅ Luckfox-Pico-Pro-Max (RV1106)

## 🚨 固件功能声明

**本固件在官方 Buildroot 镜像的基础上内置了以下应用：**

✅ FCN - 闭源且需付费使用的异地组网工具

✅ KSA - 闭源但可免费使用的异地组网工具

✅ 内核态 Wireguard 及相关工具

✅ TUN/TAP 虚拟网卡驱动支持

✅ ntp 时间同步相关工具

✅ ip(6)tables 命令支持

✅ openresolv 命令支持

✅ tcpdump 命令支持

✅ netcat 命令支持

✅ vim 命令支持

✅ ipv6 协议支持

**本固件在官方 Buildroot 镜像的基础上移除了以下应用：**

⚠️ 移除了 python 命令支持

⚠️ 移除了 samba4 命令支持

⚠️ 移除了 nano 命令支持

### 开局配置

固件基于官方 Buildroot 最小化构建，内核版本为5.10.110，默认使用 ADB/SSH/TELNET 访问系统，用户名及密码与官方固件默认保持一致，固件烧录完毕后，需手动进行网络初始化配置，ntp 服务器地址配置，以及其他必要的初始化操作

#### 1. 生成内核模块依赖信息

```bash
# 执行 insmod_ko.sh 脚本
sh /oem/usr/ko/insmod_ko.sh
```

#### 2. 修改 interfaces 配置文件

```bash
# 编辑 /etc/network/interfaces 配置文件
vim /etc/network/interfaces

# 新增 eth0 网卡配置
auto eth0
iface eth0 inet dhcp

# 固定 MAC 地址
hwaddress ether XX:XX:XX:XX:XX:XX

# 重启网络服务以应用
/etc/init.d/S40network reload
```

#### 3. 自定义 ntp 服务器地址

```bash
# 编辑 /etc/ntp.conf 配置文件
vim /etc/ntp.conf

# 修改默认的 ntp 服务器地址
```

### ⚠️ WireGuard 特殊配置要求
因固件当中缺失 stat 命令，故需执行以下必要修改：

#### 1. 修复 wg-quick 脚本兼容性

```bash
# 编辑 wg-quick 脚本
vim $(which wg-quick)

# 定位并注释掉 stat 命令所在行代码
```

### Tips:
使用本仓库中的 busybox 可以直接将开发板重启到 MaskRom 模式

```bash
# 赋予可执行权限后执行
chmod +x /path/to/busybox
/path/to/busybox reboot loader
```

[捐助列表](https://github.com/Droid-MAX/Luckfox-Pico-SDWAN/wiki/Donate‐list)

