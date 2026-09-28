# HapInstaller v1.0.0

HarmonyOS Next 端侧签名与安装工具 —— 在手机上为其他鸿蒙应用完成端侧签名与安装，无需 PC。

## 产物

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `HapInstaller-1.0.0-unsigned.hap` | 19,051,751 字节 | `bd20b09ae6cc503e2953e1e2e6ccc9e60f8de1d7b4e863ef78cb9820973c3dd5` |

> **这是未签名的 HAP。** HarmonyOS 要求 HAP 带有效签名才能安装，请先按 README「签名配置」用自己的调试证书与 Profile 对产物签名，再用 `hdc install` 或 DevEco Studio 安装。
>
> 为什么没有提供已签名的 HAP：本仓库的本地构建配置使用开发者私人的 DevEco/AGC 调试证书与 Profile，用它签出的 HAP 会内嵌**开发者账号 ID、设备 UDID 与个人证书链**，不适合公开分发。

## 功能

- **端侧 HAP 签名**：基于 hapsigntool 原生库，在手机端侧完成签名
- **端侧 HAP 安装**：基于 hdctools / hdc 原生库，进程内 hdc server，完成安装、卸载、查询
- **设备连接管理**：hdc 会话、终端交互、探活重连
- **证书 / ACL 管理**：调试证书申请、ACL 权限白名单、Profile 生成
- **历史记录与调试详情**：安装历史、日志查看、失败原因排查

## 安装前提

1. 首次安装 HapInstaller 需要先通过 PC 端工具或 DevEco Studio 签名安装（见 README「使用方式」）；
2. 端侧签名其他应用需要你自己的调试证书 / Profile（见 README「签名配置」）。

## 从源码构建

见 README 的「构建前提」「构建」两节：需要先手动拉取 hapsigntool / hdctools / openssl 等 OpenHarmony 官方源码，打上仓库内附带的 3 个补丁，再执行 hvigor 构建。

完整说明见仓库 [README](https://github.com/LMV475/hap-installer#readme)。
