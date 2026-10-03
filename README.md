# 漫画阅读器 ComicReader

一个纯原生 iOS 本地漫画阅读器，使用 SwiftUI + SwiftData 构建。支持**全格式漫画**（CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR/ePub/PDF + 图片），完全离线运行，所有数据存储在设备本地。

## 功能特性

### 书架管理

- 📚 **书架网格** — 封面缩略图、阅读进度一目了然
- 📁 **文件夹分类** — 自建文件夹（如「日漫」「美漫」「待看」），漫画可移入/移出，文件夹可重命名、删除
- 🔒 **隐私文件夹** — 文件夹可设为隐私，Face ID/Touch ID/密码验证后才显示，5 分钟自动锁定，隐私内容不出现在搜索/继续阅读/统计排行中
- ❤️ **收藏 / 喜欢** — 标记喜欢的漫画，封面爱心角标，可筛选只看收藏
- ✅ **批量操作** — 多选模式下批量删除、批量移动到文件夹、批量收藏/取消收藏
- 🏷️ **阅读状态标签** — 待看 / 在读 / 已读完 / 弃坑，自动推断或手动设置，可按状态筛选
- 🖼️ **封面自定义** — 阅读器内长按某页设为封面，或书架上下文菜单从相册选图更换封面
- 🔍 **搜索与排序** — 按标题搜索，按添加时间/阅读时间/标题/进度排序
- 📤 **导出为 CBZ** — 任意已导入漫画可重新打包为标准 CBZ 文件，通过系统分享面板保存或发送

### 阅读体验

- 📖 **流畅翻页** — 左右滑动翻页，点击屏幕两侧翻页，双击缩放
- 🔍 **双指缩放** — 支持捏合缩放和拖拽平移，双击快速放大/还原
- 🔒 **横屏锁定** — 阅读器内一键锁定当前方向，避免躺下看书时屏幕翻转
- 🎨 **阅读主题** — 白底 / 深灰 / 纯黑 / 护眼绿 / 深色棕 / 自定义图片六种背景，夜间模式自动切换
- 🖼️ **自定义背景** — 从相册选择图片作为阅读背景，可调节模糊程度和透明度
- 🎨 **强调色自定义** — 8 种强调色可选（蓝/紫/粉/红/橙/黄/绿/青），全局影响按钮、进度条、选中态
- ☀️ **亮度调节** — 阅读器内左侧边缘上下滑动调节屏幕亮度，带亮度指示器
- ⚡ **预加载下一页** — 提前解码相邻页面图片到缓存，翻页更跟手
- 🎬 **翻页动画** — 滑动 / 淡入淡出 / 无动画三种切换效果可选
- 🖼️ **图片预处理** — 自动裁剪白边、增强对比度、灰度模式
- ✨ **AI 画质增强** — 4 档可调（关闭/轻度/标准/强力），Vision 框架原生 AI 增强 + Core Image 漫画优化管线（去网点降噪、智能锐化、超分辨率），完全免费离线，Apple Neural Engine 本地推理
- 📄 **双页模式智能封面** — 横屏双页时封面页单独显示，之后奇偶页配对，日漫方向适配
- 👆 **手势自定义** — 可配置点击左/中/右区域和滑动方向对应的操作
- ↔️ **阅读方向** — 支持从左到右（普通漫画）和从右到左（日漫）两种模式
- 📄 **单/双页模式** — 单页阅读或横屏双页对开
- 💾 **阅读进度** — 自动记录阅读位置，下次打开自动续读

### 书签与统计

- 🔖 **书签系统** — 任意页添加书签，支持备注，书架和阅读器内均可查看和跳转
- 📊 **阅读统计** — 今日/本周/本月/累计时长，连续阅读天数，最近7天柱状图，漫画阅读排行

### 格式与传输

- 🗂️ **格式支持** — CBZ、ZIP、CBR（RAR，需第三方解码库）、PDF、JPG/PNG/WebP/GIF 等图片格式
- 🔄 **格式转换** — PDF 可逐页渲染后导出为 CBZ 或图片包（ZIP）；已导入漫画可重新打包为 CBZ
- 🧹 **缓存清理** — 一键清理缩略图缓存和 WiFi 传书临时文件，实时显示缓存占用，不影响漫画源文件
- 📶 **WiFi 传书** — 手机开 HTTP 服务，电脑浏览器同一 WiFi 下直接上传，无需数据线
- 📦 **全格式支持** — 基于 libarchive 原生支持 CBZ/ZIP、CBR/RAR（含RAR5）、CB7/7z、CBT/TAR、GZIP/BZIP2/XZ 等所有压缩格式，以及 ePub 电子书（解析 spine 按阅读顺序提取图片）
- 📱 **完全本地** — 所有文件存储在 App 沙盒，不上传任何数据

### 桌面小组件

- 📖 **继续阅读小组件** — 显示最近阅读漫画封面 + 阅读进度，点击直接打开阅读器续读
- 📊 **阅读统计小组件** — 显示今日阅读时长和连续阅读天数
- 📐 **小/中尺寸** — 两种小组件均支持 systemSmall 和 systemMedium
- 🔄 **自动刷新** — 通过 App Group 共享数据，App 进入后台时自动同步，Timeline 定时刷新

### 灵动岛与实时活动

- 🏝️ **灵动岛显示** — 阅读时灵动岛显示漫画标题、页码、进度百分比
- 🔒 **锁屏实时活动** — 锁屏界面展示完整阅读卡片：标题、进度条、页码、阅读时长
- 📊 **实时更新** — 翻页自动更新进度，每 30 秒刷新阅读时长
- 🖱️ **点击跳转** — 点击灵动岛或锁屏活动快速回到阅读器
- ⏸️ **后台暂停** — 切后台自动暂停计时，回前台恢复
- ⚙️ **可开关** — 设置页可启用/禁用实时活动

### Siri 快捷指令

- 🎙️ **继续阅读** — 对 Siri 说「继续阅读漫画」自动打开上次阅读的漫画
- 📖 **打开指定漫画** — 「打开 XX 漫画」，支持从漫画列表中选择
- 📊 **阅读统计** — 「阅读统计」Siri 语音播报今日阅读时长和连续天数
- 🔍 **Spotlight 集成** — 快捷指令可在 Spotlight 搜索和快捷指令 App 中使用

### 个性化

- 🎨 **自定义 App 图标** — 4 套图标可选（默认/深色版/漫画风/简约风），设置页一键切换
- 🖼️ **自定义阅读背景** — 从相册选图做背景，可调模糊和透明度
- 🎨 **强调色自定义** — 8 种强调色全局切换

## 系统要求

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## 构建运行步骤

### 第一步：创建 Xcode 项目

1. 打开 **Xcode**
2. 选择 **File → New → Project...**
3. 选择 **iOS → App**，点击 **Next**
4. 填写项目信息：
   - **Product Name**: `ComicReader`
   - **Team**: 选择你的 Apple ID（或 None）
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - 取消勾选 **Use Core Data**（我们用 SwiftData）
   - 取消勾选 **Include Tests**（可选）
5. 选择保存位置，点击 **Create**

### 第二步：添加依赖与系统库

**2.1 ZIPFoundation（用于创建 CBZ）**

1. 在 Xcode 中，选择项目文件 → **Package Dependencies** 标签
2. 点击 **+** 按钮
3. 输入包地址：`https://github.com/weichsel/ZIPFoundation.git`
4. 选择 **Up to Next Major Version**，点击 **Add Package**
5. 确认添加到 `ComicReader` target

**2.2 libarchive（全格式解压核心，系统自带）**

解压 CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR 等所有压缩格式依赖 iOS 系统自带的 libarchive，无需下载第三方库，只需链接：

1. 点击项目文件 → `ComicReader` target → **Build Phases** 标签
2. 展开 **Link Binary With Libraries**，点击 **+**
3. 搜索 `libarchive.tbd`，选中后点击 **Add**

**2.3 配置 Bridging Header（libarchive C 接口桥接）**

1. 将 `Services/libarchiveBridge.h` 拖入 Xcode 项目（勾选 Copy items if needed，确保属于 ComicReader target）
2. 点击项目文件 → `ComicReader` target → **Build Settings** 标签
3. 搜索 `Objective-C Bridging Header`
4. 设置值为：`$(SRCROOT)/ComicReader/Services/libarchiveBridge.h`（根据实际文件位置调整）

> **全格式说明**：通过 libarchive，本应用支持 CBZ/ZIP、CBR/RAR（含 RAR5）、CB7/7z、CBT/TAR、GZIP、BZIP2、XZ 等几乎所有压缩格式，以及 ePub 电子书（解析 spine 按阅读顺序提取图片）。无需额外安装任何第三方解压库。

### 第三步：替换源代码

1. 删除 Xcode 自动生成的 `ContentView.swift`
2. 将本项目 `ComicReader/` 目录下的所有 `.swift` 文件拖入 Xcode 项目（勾选 Copy items if needed）
3. 确保所有文件都属于 `ComicReader` target

### 第四步：配置 Info.plist

1. 点击项目文件 → `ComicReader` target → **Info** 标签
2. 添加以下键值（右键 → Add Row）：
   - `Supports opening documents in place` → `YES`
   - `Application supports iTunes file sharing` → `YES`（可选，方便通过电脑传输漫画）
   - `NSPhotoLibraryUsageDescription` → `用于选择漫画封面和阅读背景图片`
   - `NSFaceIDUsageDescription` → `用于验证身份以打开隐私文件夹`
   - `NSSupportsLiveActivities` → `YES`（灵动岛/实时活动功能需要）
3. 配置 URL Scheme（用于 Widget 点击和 Siri 快捷指令跳转）：
   - 在 `URL types` 中添加一项：`URL Schemes` → `comicreader`
4. 配置自定义 App 图标（可选）：
   - 参考 `Resources/Info-Icons.plist` 中的 `CFBundleIcons` / `CFBundleAlternateIcons` 配置
   - 在 `Assets.xcassets` 中为每套 alternate icon 创建对应的 App Icon 集合
   - 图标生成方法参考 `Resources/AppIcons/AppIconGeneration.md`
5. 在 `Document types` 中添加 CBZ 类型（可选）：
   - Name: `Comic Book Archive`
   - Types: `comicbook+zip`（或 `comicbook-zip`）

### 第五步：（可选）添加 Widget Extension Target

桌面小组件需要单独的 Widget Extension Target。详细步骤请参考 `Widget/WIDGET_SETUP.md`，概要如下：

1. **File → New → Target → Widget Extension**，Product Name 填 `ComicReaderWidget`
2. 删除 Xcode 自动生成的 `ComicReaderWidget.swift`
3. 将项目中 `Widget/` 目录下的文件添加到 Widget Extension target：
   - `ComicReaderWidgetBundle.swift`、`ContinueReading/`、`Stats/` → 仅 Widget Extension target
   - `Shared/WidgetDataModel.swift`、`Shared/AppGroupData.swift` → **同时**勾选主 App 和 Widget Extension 两个 target
   - `Shared/WidgetSyncManager.swift` → 仅主 App target
4. 将 `LiveActivity/` 目录下的文件加入对应 target：
   - `ReadingActivityAttributes.swift` → **同时**勾选主 App 和 Widget Extension
   - `ReadingActivityWidget.swift` → 仅 Widget Extension target
   - `LIVE_ACTIVITY_SETUP.md` → 参考文档，不需编译
   - 在 `ComicReaderWidgetBundle` 中注册 `ReadingActivityWidget()`（需 iOS 16.1+）
   - 详细配置参考 `LiveActivity/LIVE_ACTIVITY_SETUP.md`
4. 为两个 target 都添加 **App Groups** capability：`group.com.comicreader.shared`
5. Siri 快捷指令（App Intents）无需额外 target，`AppIntents/` 目录下的文件直接加入主 App target 即可

### 第六步：编译运行

1. 连接你的 iPhone（或选择模拟器）
2. 按 **Cmd + R** 编译运行
3. 如果是真机，需要在 **Settings → General → VPN & Device Management** 中信任你的开发者证书

## 使用方法

### 导入漫画

1. 将 CBZ/ZIP/PDF 文件传到 iPhone（可用 AirDrop、文件 App、iCloud 等）
2. 打开 ComicReader App
3. 点击右上角 **+** → **导入漫画文件**（支持 CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR/ePub/PDF + 图片）
4. 在文件选择器中找到你的漫画文件
5. 等待解压/渲染完成，漫画会出现在书架上

也可以选择 **导入图片**，一次选择多张图片组成一本漫画。

### 阅读操作

| 操作 | 功能 |
|------|------|
| 左右滑动 | 翻页 |
| 点击屏幕左 1/3 | 上一页（可自定义） |
| 点击屏幕右 1/3 | 下一页（可自定义） |
| 点击屏幕中间 | 显示/隐藏工具栏（可自定义） |
| 左侧边缘上下滑动 | 调节屏幕亮度 |
| 长按页面 | 设为封面 |
| 双指捏合 | 缩放 |
| 双击 | 快速放大/还原 |
| 拖拽（放大时） | 平移画面 |
| 底部滑块 | 快速跳页 |

### 日漫模式

阅读日漫时，点击阅读器右上角 **⋯** → 切换为「从右到左」方向，翻页逻辑自动适配。

### 文件夹管理

- 书架顶部横向滚动栏可按文件夹筛选（全部 / 未分类 / 各文件夹）
- 工具栏 **+文件夹** 按钮新建文件夹
- 长按文件夹胶囊可重命名或删除
- 漫画长按上下文菜单 →「移动到文件夹」

### 批量操作

1. 书架工具栏点击「编辑」进入多选模式
2. 点击漫画封面勾选/取消
3. 底部工具栏可：全选、移动到文件夹、收藏/取消收藏、删除
4. 点击「完成」退出多选模式

### WiFi 传书

不用数据线、不用 AirDrop，同一 WiFi 下用电脑浏览器直接传：

1. 书架页点右上角 **+** → **WiFi 传书**（或设置页 → WiFi 传书）
2. 点击 **开启服务**，页面会显示一个地址，如 `http://192.168.1.100:8080`
3. 确保电脑和手机连同一个 WiFi，在电脑浏览器中输入该地址
4. 在网页中选择 CBZ/ZIP/CBR/PDF 或图片文件（支持多选），点击上传
5. 上传完成后自动导入书架，可在手机上直接阅读

> 注意：传书过程中请保持 App 在前台运行。iOS 后台限制可能导致服务中断。

### 书签

- **添加书签**：阅读时点击顶部工具栏的 🔖 书签图标，当前页即被收藏（图标变橙色实心）
- **移除书签**：再次点击该书签图标即可移除
- **查看书签**：阅读器顶部点 📋 列表图标查看本书书签；书架左上角 🔖 图标查看全部书签
- **跳转**：点击书签列表中的条目直接跳转到对应页
- **备注**：长按书签可编辑备注文字
- 书架上长按某本漫画 →「查看书签」可直接看该书的书签

### 阅读统计

- 书架左上角 📊 图标进入统计页面
- 展示今日/本周/本月/累计阅读时长
- 连续阅读天数、最长连续天数、阅读天数、阅读次数
- 最近 7 天阅读时长柱状图
- 漫画阅读时长排行榜（前 10 名）
- 阅读时长自动记录，进入阅读器开始计时，退出或切后台时保存（单次不足 5 秒不计入）

### 隐私文件夹

- **创建隐私文件夹**：书架点 **+文件夹**，输入名称后开启「设为隐私文件夹」开关
- **查看隐私文件夹**：书架筛选栏右侧点 🔒 锁图标，或设置页 →「显示隐私文件夹」，通过 Face ID/Touch ID/密码验证后显示
- **自动锁定**：验证通过后 5 分钟无操作自动重新锁定，也可点锁图标手动锁定
- **隐私保护**：未解锁时，隐私文件夹及其内漫画不出现在书架、搜索结果、继续阅读、统计排行中
- **切换隐私状态**：长按文件夹胶囊 →「设为隐私/取消隐私」

### 缓存清理

- 设置页 →「存储与缓存」section 查看漫画源文件和缓存占用大小
- 点「清理缓存」确认后清理缩略图缓存和 WiFi 传书临时文件
- 清理不影响已导入的漫画源文件，封面缩略图将在下次打开时重新生成

### 格式转换与导出

- **导出漫画为 CBZ**：书架长按漫画 →「导出为 CBZ」，将已导入漫画的页面图片重新打包为标准 CBZ 文件，通过系统分享面板保存到文件 App 或发送
- **PDF 转 CBZ/图片包**：`ExportService` 提供 `exportPDFAsCBZ(_:)` 和 `exportPDFAsImagePackage(_:)` 方法，将 PDF 逐页渲染后打包
- **CBR 转换引导**：已移除，CBR（RAR）格式现已通过 libarchive 原生支持，直接导入即可

### 桌面小组件

> 需先按 `Widget/WIDGET_SETUP.md` 添加 Widget Extension Target 并配置 App Group。

- **继续阅读小组件**：长按桌面空白处 → 左上角 + → 搜索 ComicReader → 添加「继续阅读」小组件，显示最近阅读漫画封面和进度，点击直接打开阅读器
- **阅读统计小组件**：添加「阅读统计」小组件，显示今日阅读时长和连续阅读天数
- 两种小组件均支持小/中尺寸，数据通过 App Group 共享，App 进入后台时自动同步

### Siri 快捷指令

- 对 Siri 说「继续阅读漫画」自动打开上次阅读的漫画
- 对 Siri 说「打开漫画」后从列表中选择要打开的漫画
- 对 Siri 说「阅读统计」Siri 语音播报今日阅读时长和连续天数
- 也可在「快捷指令」App 中组合使用，或在 Spotlight 搜索中直接触发

### 自定义 App 图标

> 需先按 `Resources/Info-Icons.plist` 配置 Info.plist，并在 Assets.xcassets 中添加图标资源（生成方法见 `Resources/AppIcons/AppIconGeneration.md`）。

- 设置页 →「App 图标」section 查看 4 套图标预览
- 点击选择后自动切换，当前选中项有 ✓ 标记
- 4 套图标：默认（蓝色书本）、深色版、漫画风、简约风

## 项目结构

```
ComicReader/
├── ComicReaderApp.swift          # App 入口（ModelContainer、URL Scheme、Widget 同步）
├── Models/
│   ├── Comic.swift               # 漫画数据模型（含收藏、阅读状态、文件夹关系）
│   ├── Folder.swift              # 文件夹分类模型（含 isPrivate 隐私字段）
│   ├── Bookmark.swift            # 书签模型
│   ├── ReadingSession.swift      # 阅读记录模型 + 统计结构
│   └── ReaderPreferences.swift   # 阅读主题/翻页动画/手势配置枚举
├── Views/
│   ├── LibraryView.swift         # 书架首页（文件夹筛选、隐私锁定、批量操作、导出）
│   ├── ReaderView.swift          # 阅读器（主题、亮度、方向锁、手势、双页）
│   ├── SettingsView.swift        # 设置页（隐私、缓存清理、App 图标、主题等）
│   ├── WiFiTransferView.swift    # WiFi 传书页
│   ├── BookmarksView.swift       # 书签列表页
│   ├── StatsView.swift           # 阅读统计页
│   └── Components/
│       ├── ComicCoverView.swift  # 封面卡片（收藏角标、状态标签、多选状态）
│       ├── PageImageView.swift   # 可缩放页面（长按设封面）
│       └── PickerViews.swift     # 文件/图片/相册选择器
├── ViewModels/
│   ├── LibraryViewModel.swift    # 书架逻辑（隐私过滤、文件夹、批量、筛选）
│   ├── ReaderViewModel.swift     # 阅读器逻辑（图片缓存、预加载、双页布局）
│   └── StatsViewModel.swift      # 统计计算逻辑（隐私漫画排行过滤）
├── Services/
│   ├── ArchiveService.swift      # CBZ/ZIP 解压 + CBZ 创建 + CBR 接口预留
│   ├── ExportService.swift       # 格式转换与导出（CBZ/PDF转图片包/系统分享）
│   ├── PDFService.swift          # PDF 逐页渲染为图片
│   ├── ImagePreprocessor.swift   # 图片预处理（裁白边、对比度、灰度）+ AI增强集成
│   ├── ImageEnhancerService.swift # AI 画质增强（Vision AI + Core Image 漫画优化管线）
│   ├── FileStorageService.swift  # 文件存储管理 + 缓存清理
│   ├── ComicImportService.swift  # 导入流程（全格式：CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR/ePub/PDF/图片）
│   ├── libarchiveBridge.h        # libarchive C 库桥接头文件
│   ├── WiFiTransferService.swift # WiFi 传书 HTTP 服务
│   ├── PrivacyAuthService.swift  # 隐私文件夹生物识别验证（5 分钟自动锁定）
│   ├── AppIconManager.swift      # 自定义 App 图标管理
│   └── LiveActivityManager.swift # 灵动岛/实时活动管理（启动/更新/结束/暂停/恢复）
├── LiveActivity/                 # 灵动岛与实时活动（ActivityKit）
│   ├── ReadingActivityAttributes.swift  # ActivityAttributes 定义（主App+Widget双target）
│   ├── ReadingActivityWidget.swift      # 灵动岛+锁屏UI（Widget target）
│   └── LIVE_ACTIVITY_SETUP.md           # 配置指南
├── Widget/                       # 桌面小组件源码（需单独 Widget Extension Target）
│   ├── ComicReaderWidgetBundle.swift
│   ├── Shared/                   # 共享数据模型 + App Group 读写 + 同步管理器
│   ├── ContinueReading/          # 继续阅读小组件
│   ├── Stats/                    # 阅读统计小组件
│   └── WIDGET_SETUP.md           # Xcode Widget Target 配置步骤
├── AppIntents/                   # Siri 快捷指令（主 App target 编译）
│   ├── ComicEntity.swift         # 漫画 AppEntity + EntityQuery
│   ├── ContinueReadingIntent.swift
│   ├── OpenComicIntent.swift
│   ├── ShowReadingStatsIntent.swift
│   ├── AppShortcuts.swift        # 快捷指令注册
│   └── Notification+OpenComic.swift
└── Resources/
    ├── Info-Privacy.plist        # 隐私权限 Info.plist 片段
    ├── Info-Icons.plist          # 自定义图标 Info.plist 片段
    └── AppIcons/
        └── AppIconGeneration.md  # 图标 SwiftUI 生成代码与说明
```

## 数据存储

- 漫画文件：`Documents/Comics/` 目录（每本漫画一个子文件夹）
- 封面缩略图：`Caches/Thumbnails/` 目录
- 阅读记录：SwiftData 本地数据库

## 开源依赖

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) — ZIP 文件解压（MIT License）

## License

MIT
