# Windows 安装 IPA 指南（Sideloadly 免费签名）

## 前提条件

- 一台 Windows 电脑
- 一部 iPhone（iOS 17.0+）
- 一个 Apple ID（免费账号即可，无需付费开发者）
- 数据线（或同一 WiFi）

## 第一步：下载未签名 IPA

1. 打开 https://github.com/aQiuSha/ios-/actions
2. 找到最新的「构建未签名 IPA」工作流（绿色 ✓）
3. 点进去，页面最下方 **Artifacts** 区域
4. 下载 `ComicReader-unsigned-IPA`（得到一个 zip）
5. 解压得到 `ComicReader-unsigned.ipa`

## 第二步：安装 Sideloadly

1. 访问 https://sideloadly.io
2. 下载 **Windows 版本**（64-bit）
3. 安装并打开 Sideloadly
4. 首次打开会提示安装 iTunes 相关组件，按提示安装即可

## 第三步：用 Apple ID 签名 IPA

1. 打开 Sideloadly
2. **iCloud 账号**处输入你的 Apple ID（邮箱）
3. 把下载的 `ComicReader-unsigned.ipa` 拖到 Sideloadly 的 IPA 区域
4. 确认 iPhone 已连接电脑（数据线），Sideloadly 顶部能看到你的设备
5. 点 **Start** 开始签名
6. 首次会弹出 Apple ID 验证码，按提示输入
7. 等待签名+安装完成（约 1-2 分钟）

## 第四步：信任开发者证书

1. iPhone 上打开 **设置 → 通用 → VPN与设备管理**
2. 在「开发者 App」下面找到你的 Apple ID 邮箱
3. 点进去 → 点「信任」→ 确认
4. 回到桌面就能打开「漫画阅读器」了

## 注意事项

- **免费 Apple ID 签名有效期 7 天**，7 天后 App 会闪退，需要重新用 Sideloadly 签名安装一次
- 同一 Apple ID 最多同时签名 3 个 App
- 签名过程需要联网验证 Apple ID
- 如果 Sideloadly 报错 "Please sign in with an app-specific password"，去 https://appleid.apple.com 生成一个「App 专用密码」，用这个密码代替 Apple ID 密码

## 备选方案：AltStore

如果 Sideloadly 不好用，可以用 AltStore：
- https://altstore.io
- 原理相同，也是免费 Apple ID 签名，7 天有效期
- AltStore 支持 WiFi 刷新签名，到期前自动续期（需要电脑和手机同一 WiFi）

## 常见问题

**Q: 提示 "Unable to install"？**
A: 确保 iPhone 已解锁、信任电脑、iOS 版本 17.0+。

**Q: 7 天后闪退了怎么办？**
A: 重新连接电脑用 Sideloadly 签一次就行，数据不会丢。

**Q: 可以不连电脑签名吗？**
A: 可以用 AltStore 的 WiFi 刷新功能，或用「牛蛙助手」等在线签名工具（但不太稳定）。
