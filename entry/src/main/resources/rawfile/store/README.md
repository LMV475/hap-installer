# 签名证书目录

本目录用于存放端侧调试签名所需的证书与密钥材料。**这些文件包含私钥，已被 `.gitignore` 排除，不会提交到仓库。**

## 需要放置的文件

| 文件 | 说明 |
|------|------|
| `xiaobai.p12` | PKCS12 密钥库（含调试签名私钥） |
| `xiaobai-debug.cer` | 调试证书 |
| `xiaobai-debug.p7b` | 调试 Profile |
| `xiaobai.csr` | 证书签名请求 |
| `key.pem` | PEM 格式私钥（如流程需要） |

## 如何生成

1. 在 DevEco Studio 中通过 **File → Project Structure → Signing Configs** 自动生成调试签名材料；
2. 或参考 [HarmonyOS 应用签名指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/application-debugging) 手动申请；
3. 将上述文件放入本目录，并在 `build-profile.json5`（从 `build-profile.json5.example` 复制）中填写对应路径与密码。
