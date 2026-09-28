# release-assets 分支

这个分支**不是源码**，只用来存放 HapInstaller 的发布产物，供 GitHub Actions（`.github/workflows/release.yml`）上传到 GitHub Release。

## 为什么不放 main

HAP 是构建产物（约 19 MB 二进制），放进主分支会污染源码历史；`main` 的 `.gitignore` 也明确排除了构建产物与 `dist/`。这里单独用一个分支承载发布资产，`main` 保持纯源码。

## 为什么是未签名的 HAP

`entry-default-signed.hap` 是用开发者私人的 DevEco/AGC 调试证书签名的，包内会带上开发者账号 ID、设备 UDID 与个人证书链，不适合公开分发；未签名版本不含任何个人身份信息。使用前请按 README 的「签名配置」用自己的调试证书与 Profile 对产物签名，再 `hdc install`。

## 发布一个新版本

1. 在源码仓库（`main`）更新版本号、`RELEASE_NOTES.md` 的内容，打标签并推送：
   `git tag -a v1.0.0 -m "HapInstaller v1.0.0" && git push origin v1.0.0`
2. 在本分支更新：`VERSION`（内容就是标签名）、`RELEASE_NOTES.md`、HAP 产物、`SHA256SUMS.txt`；
   `SHA256SUMS.txt` 用 `sha256sum <hap>`（macOS 用 `shasum -a 256 <hap>`）生成，文件名不带路径。
3. 推送到本分支 —— Actions 会自动创建 / 更新对应标签的 Release（已存在则更新正文并覆盖同名资产）。
4. 若仓库的 Workflow permissions 是只读，需要先到 **Settings → Actions → General → Workflow permissions** 打开 “Read and write permissions”。

## 本地校验

```
sha256sum -c SHA256SUMS.txt          # Linux / CI
shasum -a 256 -c SHA256SUMS.txt      # macOS
```
