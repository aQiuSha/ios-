# GitHub Actions 自动编译指南（Windows 用户适用）

本项目已配置好 GitHub Actions 自动编译，**不需要 Mac 电脑**，推送代码后云端自动编译。

## 快速开始（3 步）

### 第 1 步：注册 GitHub 账号并创建仓库

1. 访问 https://github.com 注册账号（免费）
2. 点击右上角 **+** → **New repository**
3. 仓库名填 `ComicReader`，选 **Public** 或 **Private** 均可，点 **Create repository**

### 第 2 步：上传代码

**方式 A：网页上传（最简单）**
1. 打开刚创建的仓库页面
2. 点 **uploading an existing file**
3. 把解压后的 `ComicReader/` 文件夹里的**所有内容**拖进去（包括 `.github` 隐藏文件夹）
4. 点 **Commit changes**

**方式 B：Git 命令行（推荐）**
```bash
# 在 ComicReader 文件夹同级目录执行
cd ComicReader
git init
git add .
git commit -m "初始提交"
git branch -M main
git remote add origin https://github.com/你的用户名/ComicReader.git
git push -u origin main
```

> 注意：`.github` 文件夹是隐藏的，Windows 资源管理器默认不显示。需要在「查看」里勾选「隐藏的项目」才能看到，确保一起上传。

### 第 3 步：查看编译结果

1. 推送后，打开仓库页面 → 顶部点 **Actions** 标签
2. 会看到一个名为「编译 iOS 应用」的任务正在运行
3. 等待 3-8 分钟（首次需要下载依赖，稍慢）
4. 绿色 ✓ 表示编译成功，红色 ✗ 表示失败

### 下载编译产物

1. 编译成功后，点进那个绿色的任务
2. 页面最下方 **Artifacts** 区域有 `ComicReader-App`
3. 点击下载，得到一个 zip，里面是 `.app` 文件（模拟器版本）

---

## 两个工作流说明

| 工作流文件 | 触发方式 | 用途 | 需要签名 |
|-----------|---------|------|---------|
| `build.yml` | 每次 push 自动 | 编译模拟器版本，验证代码能否通过编译 | 不需要 |
| `build-ipa.yml` | 手动触发 | 打包真机 IPA，可装到 iPhone | 需要（见下方） |

---

## 如何装到自己的 iPhone 上

模拟器版本的 `.app` 不能直接装到真机。要装到 iPhone 需要：

### 方案 A：免费 Apple ID 签名（7 天有效期）

1. 找一台 Mac（或租云 Mac 1 小时），用 Xcode 打开项目
2. 插上 iPhone，Xcode 里选你的手机，点运行
3. 用你的 Apple ID 登录（免费账号即可）
4. iPhone 设置 → 通用 → VPN与设备管理 → 信任你的开发者证书
5. 有效期 7 天，过期后需重新编译安装

### 方案 B：GitHub Actions 打包 IPA（需配置签名）

`build-ipa.yml` 工作流支持云端打包真机 IPA，但需要在 GitHub 仓库配置 3 个 Secrets：

1. **Settings → Secrets and variables → Actions → New repository secret**
2. 添加以下 3 个：
   - `BUILD_CERTIFICATE_BASE64`：你的开发者证书 .p12 文件的 base64 编码
   - `P12_PASSWORD`：证书导出时设置的密码
   - `KEYCHAIN_PASSWORD`：自定义一个钥匙串密码
   - `PROVISIONING_PROFILE_BASE64`：描述文件 .mobileprovision 的 base64 编码
3. 配置后在 Actions 页面手动触发「打包真机 IPA」
4. 下载 Artifacts 里的 IPA，用 [AltStore](https://altstore.io) 或 [Sideloadly](https://sideloadly.io) 装到 iPhone

> 证书和描述文件需要 Apple 开发者账号（免费账号也能生成开发证书）。生成方法参考：https://developer.apple.com

---

## 常见问题

### Q: 编译失败怎么办？
A: 点进红色失败的任务，展开失败的步骤，看红色错误信息。把错误截图发我，我帮你修。

### Q: 免费额度够吗？
A: GitHub 免费账号每月 2000 分钟，macOS 按 10 倍计费即 200 分钟 macOS 时间。编译一次约 3-5 分钟，每月可编译 40-60 次，完全够用。

### Q: 可以在 Windows 上改代码吗？
A: 完全可以！用 VS Code 或任何编辑器改 `.swift` 文件，保存后 git push，云端自动重新编译。

### Q: XcodeGen 是什么？
A: 一个命令行工具，用 `project.yml` 文本文件描述 Xcode 项目结构，自动生成 `.xcodeproj`。这样就不需要手动在 Xcode 里拖文件、配 target 了，全自动化。

### Q: 本地（Mac）怎么用 XcodeGen 生成项目？
A:
```bash
brew install xcodegen
cd ComicReader
xcodegen generate
open ComicReader.xcodeproj
```
