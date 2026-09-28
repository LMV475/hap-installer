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
| ~~libusb~~ | ~~1.0.28~~ | ~~LGPL-2.1~~ | HDC 的 USB 传输后端 | **已移除**，见下 |
| lz4 | 随 hdctools | BSD-2-Clause | HDC 传输压缩 | 静态链入 `libhdc_z.so` |
| zlib | 随 hapsigner | zlib License | 压缩 | 静态链入 `libsigntool.so` |
| nlohmann/json | 随 hapsigner | MIT | Profile / 配置解析 | 静态链入 `libsigntool.so` |
| bzip2 | 随 hapsigner | bzip2 License（BSD 类） | 压缩 | 静态链入 `libsigntool.so` |
| bounds_checking_function | 随 OpenHarmony | MulanPSL-2.0 | 安全 C 字符串/内存函数 | 静态链入 |
| libc++ (LLVM) | 随 DevEco SDK | Apache-2.0 with LLVM Exception | C++ 运行库 | `libc++_shared.so` |

上述组件均为**宽松许可证**（Apache-2.0 / MIT / BSD / zlib / MulanPSL-2.0），再分发时仅需保留版权声明与许可证原文。

## libusb 已移除（LGPL-2.1 依赖已消除）

本项目的早期构建曾通过 `entry/src/main/cpp/hdctools/CMakeLists.txt` 中的 `usb` 静态库目标，把 **libusb 1.0.28** 静态链接进 `libhdc_z.so`。libusb 采用 **LGPL-2.1**，静态链接会带来「保证接收者能够以修改后的 libusb 重新链接本作品」的义务。

该依赖现已**完全移除**：

- `CMakeLists.txt` 删除了 libusb 的头文件目录、静态库目标与 `usb` 链接项，并新增全局宏 `-DHDC_NO_USB`；
- `source/src/host/host_usb.cpp`（libusb 传输后端）不再参与编译；
- `host_usb.h` 在 `HDC_NO_USB` 下退化为 no-op 桩类，因此 `server.cpp` / `server.h` 无需改动；
- 上游 `source/` 内的相应改动以 `entry/src/main/cpp/hdctools/fix_no_libusb.patch` 分发（应用步骤见 README）。

验证（`libhdc_z.so`）：`nm -D | grep -c libusb_` = **0**（移除前 `106`）；`strings | grep -ci libusb` = **0**（移除前 `638`）；`.hap` 内打包的副本同样为 `0`。

**代价**：HDC 的 **USB 主机传输后端不再可用**（TCP 与 UART 后端不受影响）。若你确实需要 USB 直连，可自行恢复该后端——届时 LGPL-2.1 义务随之回归，请重新评估。

> **历史立场（现已不适用）**：移除前的论证是「公开全部自有源码与构建脚本供他人替换 libusb 后重新链接、使用未修改的标准上游 1.0.28、不转授其许可证条款」。当前构建已不含任何 libusb 代码，无需该论证。


## 许可证原文获取

为控制仓库体积，本项目未将第三方源码纳入版本管理（见 [.gitignore](.gitignore)）。构建前需自行拉取，各源码包内均含其许可证原文：

| 组件 | 获取位置 |
|------|----------|
| HDC | OpenHarmony `developtools_hdc`（源码包内 `LICENSE`） |
| hapsigner | OpenHarmony `security_hapsigntool`（源码包内 `LICENSE`、`NOTICE`） |
| OpenSSL | OpenHarmony third_party_openssl 或 https://www.openssl.org/source/ |
| ~~libusb~~ | 已移除，无需获取 |
| lz4 | OpenHarmony third_party_lz4（`lib/LICENSE`） |
| zlib | https://zlib.net/（源码包内 `LICENSE`） |
| nlohmann/json | https://github.com/nlohmann/json（`LICENSE.MIT`） |
| bzip2 | https://sourceware.org/bzip2/（源码包内 `LICENSE`） |
| bounds_checking_function | OpenHarmony third_party_bounds_checking_function（源码包内 `LICENSE`） |

## 免责

本文件仅为便利性说明，不构成法律意见。就具体使用场景的合规判断，请咨询专业人士。
