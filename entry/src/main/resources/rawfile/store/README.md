# 签名证书目录

本目录用于存放端侧调试签名所需的证书与密钥材料。**这些文件包含私钥，已被 `.gitignore` 排除，不会提交到仓库。**

## 需要放置的文件

| 文件 | 说明 |
|------|------|
| `hapinstaller.p12` | PKCS12 密钥库（含调试签名私钥，alias=`hapinstaller`，口令 `hapinstaller123`） |
| `hapinstaller-builtin.cer` | 内置调试证书链（三级：Root CA → App Signature Service CA → Debug） |
| `hapinstaller-builtin.p7b` | 内置调试 Profile（已签名） |
| `hapinstaller.csr` | 证书签名请求（用于向 AGC 申请正式调试证书） |
| `hapinstaller.pem` | PEM 格式私钥（如流程需要） |

> 仓库默认内置的是一套**自签名测试证书链**（由 `hap-sign-tool` 生成，非华为 CA 签发），仅用于本地功能验证。正式调试请通过 DevEco Studio 或 AGC 获取华为签发的证书材料，命名保持 `hapinstaller-debug.cer` / `hapinstaller-debug.p7b`（代码会优先采用）。

## 如何生成

### 方式一：DevEco Studio 自动生成（推荐）

1. 通过 **File → Project Structure → Signing Configs → Fix** 自动生成调试签名材料；
2. 将生成的 `.p12` / `.cer` / `.p7b` 放入本目录，并在 `build-profile.json5`（从 `build-profile.json5.example` 复制）中填写对应路径与密码。

### 方式二：用 hap-sign-tool 自行生成自签名测试链

`hap-sign-tool.jar` 位于 DevEco SDK 的 `toolchains/lib/` 下。按以下顺序生成（示例口令 `hapinstaller123`）：

```bash
JAR=$DEVECO_SDK/toolchains/lib/hap-sign-tool.jar

# 1) 应用密钥库
java -jar $JAR generate-keypair -keyAlias hapinstaller -keyPwd hapinstaller123 \
  -keyAlg ECC -keySize NIST-P-256 \
  -keystoreFile hapinstaller.p12 -keystorePwd hapinstaller123

# 2) 根 CA（自签名）
java -jar $JAR generate-ca -keyAlias hapinstaller-root-ca -keyPwd hapinstaller123 \
  -keyAlg ECC -keySize NIST-P-256 \
  -subject "C=CN,O=HapInstaller,OU=HapInstaller Community,CN=HapInstaller Root CA" \
  -validity 3650 -signAlg SHA256withECDSA \
  -keystoreFile hapinstaller-root-ca.p12 -keystorePwd hapinstaller123 \
  -outFile hapinstaller-root-ca.cer

# 3) 应用签名子 CA / Profile 签名子 CA（issuer 用上一步的 root CA，issuerKeystoreFile 指向 root-ca.p12）
# 4) 应用调试证书链：generate-app-cert ... -outForm certChain -outFile hapinstaller-builtin.cer
# 5) Profile 调试证书链：generate-profile-cert ... -outForm certChain -outFile hapinstaller-profile-debug.cer
# 6) CSR：generate-csr -keyAlias hapinstaller ... -outFile hapinstaller.csr
# 7) Profile 签名：sign-profile -profileCertFile hapinstaller-profile-debug.cer \
#      -inFile <profile.json> -outFile hapinstaller-builtin.p7b
#    （profile.json 的 bundle-info.development-certificate 需内嵌应用调试证书 PEM）
# 8) 导出私钥：openssl pkcs12 -in hapinstaller.p12 -nocerts -nodes -out hapinstaller.pem
```

详见项目根目录 `README.md` 的「签名配置」章节。
