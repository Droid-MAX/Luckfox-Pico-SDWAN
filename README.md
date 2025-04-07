# Luckfox-Pico 系列开发板异地组网镜像使用说明

[![CC BY-NC-SA 3.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%203.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/3.0/)

## 🚨 兼容性声明
**本固件仅适配以下开发板型号：**
✅ Luckfox-Pico-Plus (RV1103G)
✅ Luckfox-Pico-Pro-Max (RV1106)

## 🚨 内置应用声明
**本固件在官方 Buildroot 镜像的基础上内置了以下应用：**
✅ FCN - 闭源且需付费使用的异地组网工具
✅ KSA - 闭源但可免费使用的异地组网工具
✅ 内核态 Wireguard 及相关工具
✅ ntp 时间同步相关工具
✅ 防火墙及 iptables 支持
✅ ipv6 协议支持

### 开局配置
固件基于官方 Buildroot 最小化构建，默认使用 ADB/SSH 访问系统，用户名及密码与官方固件默认保持一致，固件烧录完毕后，需手动配置 ntp 服务器地址，固定 MAC 地址

#### 1. 自定义 ntp 服务器地址

```bash
# 编辑 /etc/ntp.conf 配置文件
vi /etc/ntp.conf

# 修改默认的 ntp 服务器地址
```

#### 2. 固定 MAC 地址

```bash
# 编辑 /usrdata/ethaddr.txt 配置文件
vi /usrdata/ethaddr.txt

# 填入合法的 MAC 地址后保存退出，重启网络服务或者重启系统
```

### ⚠️ Wireguard 特殊配置要求
因固件当中缺失 stat/resolvconf 命令，故需执行以下必要修改：

#### 1. 修复 wg-quick 脚本兼容性

```bash
# 编辑 wg-quick 脚本
vi $(which wg-quick)

# 定位并注释掉 stat 命令所在行代码
```

#### 2. Wireguard 配置文件限制说明

```bash
# ✅ 合法配置示例
[Interface]
PrivateKey = xxxxxxxxx
Address = 10.8.0.2/24
MTU = 1280

# ❌ 禁止包含以下字段（固件无resolvconf支持）：
DNS = 8.8.8.8

# 手动配置DNS（如需）：
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```
