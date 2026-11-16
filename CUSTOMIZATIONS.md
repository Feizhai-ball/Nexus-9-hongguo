# Nexus 9 定制记录

目标设备：Nexus 9（Flounder，Tegra K1）  
目标应用：[N3urda/hongguoTV](https://github.com/N3urda/hongguoTV)  
定制版本：基于项目当时的 Kotlin 版本（本地基线标签 `kotlin-v0.16.6`）

> 本文是对个人设备适配工作的事实记录，不是 hongguoTV 官方文档。hongguoTV 名称及相关代码权利归其各自权利人所有。本仓库不声称拥有上游项目或第三方内容的权利。

## 修改动机

原应用以 Android TV 的遥控器/方向键交互为主要设计方向，而 Nexus 9 是触摸平板。保留全部电视焦点导航会让平板操作显得绕、不自然。本次修改集中于触摸操作适配，并避免改变应用的核心播放流程。

## 修改项目

### 1. 桌面名称：HGTV

- 修改：`kotlin-tv/app/build.gradle.kts` 中两处 `manifestPlaceholders["appLabel"]`，将桌面显示名称改为 `HGTV`。
- 原因：区分 Nexus 9 定制版本和上游原版，方便在设备桌面识别。
- 保留：`applicationId` 仍为 `com.hongguotv.nativeapp`，不因改名而改变应用包身份。
- 验证：Nexus 9 桌面显示 HGTV。

### 2. 触摸点击模式

- 修改范围：17 个 Kotlin 文件，累计约 52 处调整。
- 涉及文件：
  - `AccountController.kt`
  - `AppUpdater.kt`
  - `CatalogShell.kt`
  - `ContinuousCatalogView.kt`
  - `DiscoveryScreen.kt`
  - `EpisodePanel.kt`
  - `HomeFeedScreen.kt`
  - `HomeScreen.kt`
  - `HomeSpotlight.kt`
  - `MainActivity.kt`
  - `ProducerWorksDialog.kt`
  - `RankingScreen.kt`
  - `RelatedWorksView.kt`
  - `SearchSuggestionsView.kt`
  - `TvSearchPanel.kt`
  - `TvSocial.kt`
  - `TvTools.kt`
- 原因：让平板用户直接点击页面项目和操作控件，而不是依赖电视遥控器的焦点移动流程。
- 保护：保留 EditText 文本输入行为，并避免覆盖 MainActivity 中播放器媒体按键和 seek 处理。
- 验证：用户在 Nexus 9 上确认整体触摸表现正常。

### 3. 播放器画面点击显示/隐藏菜单

在播放器视图的点击事件中增加切换行为：当当前页面为播放器且没有播放错误时，点击视频区域切换播放菜单显示状态；非播放器页面或播放错误状态不触发。

- 修改位置：上游项目的播放器界面实现（`MainActivity.kt` 中 PlayerView 创建及事件处理附近）。
- 原因：视频画面是触屏设备上最直观的播放控制入口，单击显示/隐藏菜单符合常见播放器交互习惯。
- 验证：Nexus 9 实机上点击画面呼出/隐藏菜单正常；选集播放和菜单自动隐藏正常。

本文仅以文字描述适配行为，不在此重复转载上游项目的实现代码。需要查看具体实现时，请从上游项目仓库及其适用许可证获取对应源码。

### 4. 明确不修改的部分

- 不修改播放进度条及其拖动行为。
- 不改变应用包名。
- 不主动改写播放器媒体按键/seek 逻辑。
- 不改变内容源、账号、网络请求或播放核心实现。

## 构建与设备

已验证环境记录：

- Ubuntu 24.04.4 LTS
- Gradle 8.14.3
- Nexus 9，Android 7.1.1（API 25）
- 推荐构建并安装 `armeabi-v7a` APK

构建命令：

```bash
cd kotlin-tv
~/软件/gradle-8.14.3/bin/gradle :app:assembleDebug
```

预期 32 位 APK：

```
app/build/platform/outputs/apk/debug/app-armeabi-v7a-debug.apk
```

## 维护提示

这些修改属于针对特定平板设备的适配。上游重构 UI、播放器或输入事件时，rebase 可能产生冲突，也可能出现能够编译但交互回归的情况。每次同步后，至少重新检查桌面名称、主要页面触摸点击、搜索输入、播放器菜单、选集播放和媒体按键。

上游项目采用 GPL-3.0。若公开分发包含或基于上游代码的修改版本，应核对 GPL-3.0 的源码提供、许可证文本、版权声明、修改标记等义务。请勿将本仓库的 MIT 许可理解为对上游代码、第三方依赖、名称或内容的授权。
