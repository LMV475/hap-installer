# 第三方组件与许可证声明

本文件列出 HapInstaller 在构建时链接并打包进最终产物（`.hap` 内的 `libsigntool.so`、`libhdc_z.so`、`libc++_shared.so`）的第三方开源组件、版本与许可证。

> **适用范围**
> 本仓库以**源码**形式分发。若你以**二进制**形式再分发构建产物（例如在 GitHub Releases 上传 `.hap`），须随附本文件，并同时提供下表各组件的完整许可证原文（获取途径见文末）。

## 组件清单

| 组件 | 版本 | 许可证 | 用途 | 形态 |
|------|------|--------|------|------|
| HDC (`hdctools`) | 3.2.1 (`HDC_VERSION_NUMBER = 0x30200100`) | Apache-2.0 | 端侧设备连接与安装通道 | 源码编入 `libhdc_z.so` |
| hapsigner (`hap-sign-tool`) | 随 DevEco SDK | Apache-2.0 | 端侧 HAP 签名与校验 | `libsigntool.so` |
| OpenSSL | 3.2.0 | Apache-2.0 | 签名/验签的密码学原语 | `libcrypto.a`、`libssl.a` 静态链入 |
| **libusb** | **1.0.28** | **LGPL-2.1** ⚠️ | HDC 的 USB 传输后端 | 静态链入 `libhdc_z.so` |
| lz4 | 随 hdctools | BSD-2-Clause | HDC 传输压缩 | 静态链入 `libhdc_z.so` |
| zlib | 随 hapsigner | zlib License | 压缩 | 静态链入 `libsigntool.so` |
| nlohmann/json | 随 hapsigner | MIT | Profile / 配置解析 | 静态链入 `libsigntool.so` |
| bzip2 | 随 hapsigner | bzip2 License（BSD 类） | 压缩 | 静态链入 `libsigntool.so` |
| bounds_checking_function | 随 OpenHarmony | MulanPSL-2.0 | 安全 C 字符串/内存函数 | 静态链入 |
| libc++ (LLVM) | 随 DevEco SDK | Apache-2.0 with LLVM Exception | C++ 运行库 | `libc++_shared.so` |

上述组件中除 **libusb** 外均为宽松许可证，再分发时仅需保留版权声明与许可证原文。

## ⚠️ 关于 libusb 与 LGPL-2.1

libusb 采用 **GNU Lesser General Public License v2.1**，且在本项目中是**静态链接**进 `libhdc_z.so` 的（见 `entry/src/main/cpp/hdctools/CMakeLists.txt` 中的 `usb` 静态库目标）。LGPL-2.1 允许静态链接，但要求分发者保证接收者**能够以修改后的 libusb 重新链接本作品**。

本项目的合规立场：

1. 本仓库以 Apache-2.0 公开**全部自有源码**与完整构建脚本（`CMakeLists.txt`、`build-profile.json5.example`、README 中的构建步骤），任何人可自行替换 libusb 源码后重新构建产物；
2. 所使用的 libusb 为标准上游 **1.0.28** 版本，**未作任何修改**，可直接从上游获取；
3. 本项目**不修改也不转授** libusb 本身的许可证条款。

**若你以二进制形式再分发**，除本文件外还应附带 libusb 的 LGPL-2.1 完整原文及源码获取途径。若你的使用场景不接受 LGPL 依赖，可考虑：将 libusb 改为动态链接（`add_library(usb SHARED ...)`），或在构建时排除 hdc 的 USB 传输后端（需同步改动上游 `source/src/host/` 下的 `host_usb.cpp`、`server.h`、`server.cpp`、`main.cpp`）。

## 许可证原文获取

为控制仓库体积，本项目未将第三方源码纳入版本管理（见 [.gitignore](.gitignore)）。构建前需自行拉取，各源码包内均含其许可证原文：

| 组件 | 获取位置 |
|------|----------|
| HDC | OpenHarmony `developtools_hdc`（源码包内 `LICENSE`） |
| hapsigner | OpenHarmony `security_hapsigntool`（源码包内 `LICENSE`、`NOTICE`） |
| OpenSSL | OpenHarmony third_party_openssl 或 https://www.openssl.org/source/ |
| libusb | OpenHarmony third_party_libusb 或 https://libusb.info/（源码包内 `COPYING`） |
| lz4 | OpenHarmony third_party_lz4（`lib/LICENSE`） |
| zlib | https://zlib.net/（源码包内 `LICENSE`） |
| nlohmann/json | https://github.com/nlohmann/json（`LICENSE.MIT`） |
| bzip2 | https://sourceware.org/bzip2/（源码包内 `LICENSE`） |
| bounds_checking_function | OpenHarmony third_party_bounds_checking_function（源码包内 `LICENSE`） |

## 免责

本文件仅为便利性说明，不构成法律意见。就具体使用场景的合规判断，请咨询专业人士。
