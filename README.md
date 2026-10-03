# HapInstaller

> HarmonyOS Next 端侧签名与安装工具 — 在手机上完成其他鸿蒙应用的端侧签名与侧载安装。

本项目是一个 HarmonyOS Next 应用，功能设计参考了 [小白调试助手（auto-installer）](https://github.com/likuai2010/auto-installer)。小白调试助手是 Flutter / Dart 实现的 PC 端工具，用于在 Windows / macOS / Linux 上为鸿蒙设备侧载安装 HAP/HSP/APP 应用。本应用把端侧签名与安装能力搬到 HarmonyOS Next 手机端：装上它之后，无需 PC 也能在手机上完成 HAP 包的签名与安装。

## 与小白调试助手的关系

HapInstaller 与小白调试助手分工如下：

1. **首次安装靠它**：HapInstaller 本身无法在未签名状态下直接安装到手机，首次需要先在 PC 上用[小白调试助手](https://github.com/likuai2010/auto-installer)把本应用安装到手机；
2. **之后独立运行**：装进手机后，HapInstaller 即可独立完成其他鸿蒙应用的端侧签名与安装，不再需要 PC。

简而言之：**小白调试助手（PC）把 HapInstaller 装进手机 → 之后应用的签名与安装全部在手机端完成**。

证书材料的来源与生成方式见下文「[签名配置](#签名配置)」章节。

## 功能

- **端侧 HAP 签名**：基于 hapsigntool 原生库，在手机端完成 HAP 包签名（默认使用自签名测试证书链，需自行配置）
- **端侧 HAP 安装**：基于 hdctools / hdc 原生库，在手机端完成 HAP 包安装、卸载、查询
- **设备连接管理**：进程内 hdc server、终端命令交互、断连会话探活
- **证书 / ACL 管理**：调试证书申请、ACL 权限白名单管理、Profile 生成
- **历史记录与调试详情**：安装历史、日志查看、调试详情排查

## 技术栈

- **ArkTS / ArkUI** — 前端页面与组件
- **C/C++ NAPI** — 端侧原生能力桥接（hdctools / hapsigner）
- **HarmonyOS 6.0.1 (API 21)** — 目标平台

## 项目结构

```
HapInstaller/
├── AppScope/                    # 应用级配置与资源
├── entry/                       # 主模块
│   ├── src/main/
│   │   ├── ets/                 # ArkTS 业务代码（页面/组件/common/workers）
│   │   ├── cpp/                 # C++ 原生代码
│   │   │   ├── hdctools/        # 自有 NAPI 桥接代码
│   │   │   ├── hapsigner/       # 第三方（需手动获取，见下）
│   │   │   ├── third_party/     # 第三方依赖（需手动获取，见下）
│   │   │   ├── types/           # NAPI 类型声明
│   │   │   └── CMakeLists.txt
│   │   ├── resources/           # 资源文件（含内置调试证书 store/）
│   │   └── module.json5         # 模块配置
│   ├── build-profile.json5      # 模块构建配置
│   └── obfuscation-rules.txt
├── tools/                       # 本地辅助脚本（上游补丁 / AGC 启用停用）
├── build-profile.json5.example  # 签名配置模板（脱敏）
└── oh-package.json5
```

## 构建前提

本项目依赖若干 HarmonyOS 官方开源组件，体积较大且各有独立 git 仓库，**未纳入本仓库**。首次构建前需手动拉取（拉取后保持目录结构与 `CMakeLists.txt` 的引用路径一致）：

- **hapsigntool 源码** — [developtools_hapsigner](https://gitee.com/openharmony/developtools_hapsigner) → `entry/src/main/cpp/hapsigner/source/`
- **zlib** — [zlib](https://gitee.com/openharmony/zlib) → `entry/src/main/cpp/hapsigner/third_party/zlib/source/`
- **json (nlohmann)** — [json](https://gitee.com/openharmony/json) → `entry/src/main/cpp/hapsigner/third_party/json/source/`
- **bzip2** — [bzip2](https://gitee.com/openharmony/bzip2) → `entry/src/main/cpp/hapsigner/third_party/bzip2/source/`
- **bounds_checking_function** — [security_safelibs](https://gitee.com/openharmony/security_safelibs) → `entry/src/main/cpp/third_party/bounds_checking_function/`
- **hdctools 源码** — [developtools_hdc](https://gitee.com/openharmony/developtools_hdc) → `entry/src/main/cpp/hdctools/source/`
- **openssl 预编译库** — 自行交叉编译 [openssl](https://gitee.com/openharmony/openssl) → `entry/src/main/cpp/third_party/openssl/`

两点说明：

- **libusb 无需拉取**：它已从构建中移除（LGPL-2.1 合规，见 `fix_no_libusb.patch`）；
- openssl 预编译库只需提供 `arm64-v8a`（与 `entry/build-profile.json5` 的 `abiFilters` 一致，缺 `armeabi-v7a` 不影响构建）。

### 应用上游补丁（必需，不可跳过）

上游源码中包含本项目的端侧适配改动，这些改动以补丁形式随仓库分发：

- `entry/src/main/cpp/hapsigner/fix_ohos.patch` → 应用于 `entry/src/main/cpp/hapsigner/source/`
  端侧签名适配：单线程签名池、`HandleZipGlobalInfo` 串行化、签名失败详情写入沙箱 `sign.out`
- `entry/src/main/cpp/hdctools/fix_no_libusb.patch` → 应用于 `entry/src/main/cpp/hdctools/source/`
  摘除 libusb（LGPL-2.1 合规），USB 后端以 no-op 桩类替代
- `entry/src/main/cpp/hdctools/fix_sandbox_paths.patch` → 应用于 `entry/src/main/cpp/hdctools/source/`
  沙箱适配：`Base::SetTempDir()` 与 hdc 的 UDS 套接字路径

```bash
cd entry/src/main/cpp/hapsigner/source && patch -p1 --forward < ../fix_ohos.patch
cd entry/src/main/cpp/hdctools/source  && patch -p1 --forward < ../fix_no_libusb.patch
cd entry/src/main/cpp/hdctools/source  && patch -p1 --forward < ../fix_sandbox_paths.patch
```

或直接执行随仓库提供的脚本（等价，并且会自动先把源码树归一化为 LF 行尾）：

```bash
bash tools/apply-upstream-patches.sh
```

三个补丁都必须打，漏打的后果各不相同：

- 漏打 `fix_sandbox_paths.patch` → **直接编译失败**：`hdctools/main.cpp` 调用了只有该补丁才引入的 `Base::SetTempDir()`；
- 漏打 `fix_ohos.patch` → 编译通过，但签名失败时 UI 读到的 `sign.out` 为空，只显示「失败」而无原因（功能静默失效，比编译失败更难发现）；
- 漏打 `fix_no_libusb.patch` → 编译通过，但 USB 后端连同 LGPL-2.1 依赖被重新引入（合规问题静默回归）。

> **行尾必须是 LF。** 上游 git 仓库中这些文件本身是 LF，三个补丁也按 LF 生成。
> 若你的 `core.autocrlf=true`（Windows 下 git 的默认值），检出会变成 CRLF，补丁将**所有 hunk 匹配失败**。此时先把源码树归一化回 LF：
>
> ```bash
> for d in hapsigner hdctools; do
>   s="entry/src/main/cpp/$d/source"
>   git -C "$s" config core.autocrlf false
>   git -C "$s" rm --cached -r -q . && git -C "$s" reset --hard -q
> done
> ```
>
> 用 `--forward` 可跳过已应用的 hunk，便于重复执行；若改用 `git apply`，请确保工作树是刚拉取的原始上游。

## 未开源模块

以下文件因依赖外部未公开服务或含敏感信息，**未纳入本仓库**（已 `.gitignore`），仅本地保留，需自行实现或获取：

- **`entry/src/main/ets/common/AgcService.local.ets`** — 依赖华为 AGC 服务的本地可选实现（证书申请、Profile 生成、设备管理、登录态）。该实现不随仓库分发；入库的 `AgcService.ets` 是不含实现的功能空壳（stub），仅保留接口签名以保证 `clone` 后可编译。
- **`build-profile.json5`（根目录）** — 含签名密码，从 `build-profile.json5.example` 复制后填写。
- **`entry/src/main/resources/rawfile/store/*.{p12,pem,cer,p7b,csr}`** — 调试签名私钥与证书，需自行生成（见该目录 README）。

> `AgcService.ets` 的 stub 语义：所有方法要么返回空值（`isLoggedIn()` 恒为 `false`，查询类返回空集合），要么抛出明确的「未实现」错误。因此 `clone` 后可直接编译，但 AGC 相关功能不可用。
> 若你本地保留了完整实现，可用 `tools/enable-agc.sh` 覆盖启用、`tools/disable-agc.sh` 恢复 stub。**启用期间请勿使用 `git commit -a` / `git add .`**，以免把本地实现提交进仓库。

## 签名配置

1. 复制 `build-profile.json5.example` 为 `build-profile.json5`；
2. 在 DevEco Studio 中生成调试签名材料（`File → Project Structure → Signing Configs → Fix`）；
3. 把证书材料放入 `entry/src/main/resources/rawfile/store/`（见该目录 README）：默认走 `hap-sign-tool` 生成的自签名测试证书链（alias=`hapinstaller`，需自行生成）；如需华为签发的正式调试材料，请通过 DevEco Studio 或 AGC 获取；
4. 在 `build-profile.json5` 中填写签名路径与密码。

> **内置测试链的材料不随仓库分发（先读这条）**：应用默认就走内置测试链（`matSource = 'builtin'`，见 `entry/src/main/ets/pages/Home.ets`），而 `entry/src/main/resources/rawfile/store/` 下的 `hapinstaller.p12`、`hapinstaller-builtin.cer`、`hapinstaller-builtin.p7b` 已在 `.gitignore` 中。因此**克隆后首次启动必然提示「材料不完整（缺少：密钥库 / 证书链 / Profile）」**——这是预期行为，不是 bug（`releaseBuiltin()` 有 try/catch，只记日志、不会崩）。按第 3 步生成并放入材料后，应用首次启动会自动回填，无需手动选择。

## 构建

用 DevEco Studio 打开本项目直接构建即可。

若走命令行，先让 DevEco 的 SDK 与 Node 能被找到——这是最容易卡住的一步：

```bash
# macOS
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
NODE=/Applications/DevEco-Studio.app/Contents/tools/node/bin/node
HVIGOR=/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js

# Windows（Git Bash；路径按你的安装位置调整）
export DEVECO_SDK_HOME="C:/Program Files/Huawei/DevEco Studio/sdk"
NODE="C:/Program Files/Huawei/DevEco Studio/tools/node/node.exe"
HVIGOR="C:/Program Files/Huawei/DevEco Studio/tools/hvigor/bin/hvigorw.js"

"$NODE" "$HVIGOR" --mode module -p product=default --no-daemon assembleHap
```

> - 未设置 `DEVECO_SDK_HOME` 会直接报 `00303217 Invalid value of 'DEVECO_SDK_HOME'`。
> - `hvigorw` 需要 Node；若 Node 不在 `PATH` 中，请像上面那样用 DevEco 自带的 Node 显式调用。
> - 产物为 `entry/build/default/outputs/default/entry-default-signed.hap`（签名材料齐备时）与 `entry-default-unsigned.hap`。

## 使用方式

1. 在 PC 上安装[小白调试助手](https://github.com/likuai2010/auto-installer)；
2. 用小白调试助手将构建好的 HapInstaller HAP 安装到手机；
3. 在手机上打开 HapInstaller，选择待安装的 HAP 包，完成端侧签名后安装。

## 致谢

- [小白调试助手 / auto-installer](https://github.com/likuai2010/auto-installer) — 功能设计参考
- [OpenHarmony](https://gitee.com/openharmony) — hapsigntool / hdctools / openssl 等官方组件

## 许可

本项目代码采用 Apache License 2.0。第三方依赖遵循各自许可证。
