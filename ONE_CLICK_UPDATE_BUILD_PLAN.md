# Nexus 9 一键同步上游、应用定制并构建 APK 方案

本文定义 Nexus 9 定制版 hongguoTV 的长期维护流程：从上游获取新版本，在独立工作区重放已确认的定制，再执行检查、测试和 APK 构建。本文是自动化方案和实施清单，不表示下文规划中的新脚本已经完成。

## 1. 目标与边界

目标是把日常更新收敛为一次命令：

```bash
./nexus9-update-build.sh
```

理想流程：

1. 获取上游最新提交。
2. 创建独立、可回收的构建工作区，不碰用户正在使用的工作树。
3. 按确定顺序重放 Nexus 9 定制提交。
4. 检查被移除的功能没有被上游重新引入，并检查触摸和播放器适配点。
5. 执行单元测试。
6. 构建 Debug APK。
7. 检查 APK、输出版本信息和 SHA-256。
8. 将 APK 与构建摘要放入独立输出目录。
9. 默认不安装、不推送、不创建 GitHub Release；需要时由用户明确执行。

脚本遇到冲突、文件结构变化、测试失败或 APK 产物不唯一时必须停止并报告，不能猜测、强制覆盖或静默跳过检查。

## 2. 当前已知版本与工作区

- 上游仓库：`https://github.com/N3urda/hongguoTV.git`
- 上游默认分支：`main`（查询时确认）。
- 本地恢复工作区：`$HOME/hongguoTV-v0166-recovery/kotlin-tv`
- 当前恢复分支：`recovery/hgtv-custom-0166`
- 当前基线标签：`kotlin-v0.16.6`
- 基线提交：`6672b55d5308ea1ec26d2fe0bc0b2401ef4aa0c3`

另一个旧版更新脚本采用 `origin/main` 与本地分支 `hgtv-custom` 的约定。它与当前恢复工作区的分支名不同。正式启用下一版自动化前，必须明确统一远程名、上游分支和定制分支；不要直接把当前恢复分支改名或强制重置。

## 3. 已记录的 Nexus 9 定制功能

| 模块 | 定制内容 | 当前记录 |
|---|---|---|
| 应用标识 | 桌面显示名称为 HGTV；保留原 applicationId | 既有文档记录 |
| 触摸交互 | 主要页面按触摸操作；保留必要的方向键/焦点能力 | 既有定制记录 |
| 首次点击焦点修复 | 7 个 Kotlin 文件中 10 处 `isFocusableInTouchMode = true` 改为 `false`，保留 `isFocusable = true` 和原点击回调 | 2026-11-19 已在 Nexus 9 验证第一次触摸即可执行 |
| 播放器画面 | 轻点视频区域切换完整播放菜单 | 既有定制记录 |
| 左右滑动切集 | 左滑下一集、右滑上一集；短距离轻点切换完整播放菜单；斜向手势不切集；每次手势最多切一集 | 2026-11-19 已在 Nexus 9 验证左右滑动正常 |
| 手机控制功能 | 移除手机控制台、扫码遥控器、局域网控制服务及专用测试 | 既有定制记录 |
| 评论、剧评、弹幕 | 移除入口、弹幕设置/面板、时间轴覆盖层、专用网络实现、专用测试和表情资源 | 既有定制记录及回归验收 |
| 播放器核心 | 保留播放、暂停、选集、清晰度、音轨、播放恢复和进度同步 | 保留项 |
| 进度条 | 不改变原有拖动行为 | 保留项 |
| 输入与遥控器 | 保留 EditText 输入、媒体按键、seek 和方向键导航 | 保留项 |

### 3.1 首次点击焦点修复的文件分布

| 文件 | 本轮修改数 |
|---|---:|
| `MainActivity.kt` | 1 |
| `EpisodePanel.kt` | 1 |
| `HomeFeedScreen.kt` | 2 |
| `TvTools.kt` | 1 |
| `HomeScreen.kt` | 2 |
| `ProducerWorksDialog.kt` | 1 |
| `RelatedWorksView.kt` | 2 |
| **合计** | **10** |

这次修改没有删除焦点能力；方向键与确定键仍应作为每次更新后的回归项目。

### 3.2 左右滑动手势实现

新增 `EpisodeSwipeTracker.kt` 和 `EpisodeSwipeTrackerTest.kt`。测试覆盖左右滑动、轻点、斜向移动、禁用切集、重复触发和取消手势等 7 种情况。

手势只应在播放器允许切集的状态下生效。菜单/子面板、播放错误、首帧等待等状态必须继续遵循现有保护逻辑。不要把 D-pad 左右键改为切集；其原有快退/快进语义应保留。

## 4. 推荐的长期 Git 结构

建议把一个“已验证功能”整理成一个独立、可审查的定制提交。定制提交组成一条基于上游的线性历史：

```text
N3urda/hongguoTV main
        |
        +-- HGTV application label
        +-- remove phone-control feature
        +-- remove comments/reviews/danmaku
        +-- Nexus 9 touch adaptation
        +-- fix first-touch focus behavior
        +-- add player episode swipe
        +-- other individually reviewed adaptations
```

建议的提交边界：

- `custom: set Nexus 9 app label`
- `remove: phone control and QR remote`
- `remove: comments reviews and danmaku`
- `fix: make touch controls activate on first tap`
- `feat: switch episodes with horizontal player swipe`

不要把无关功能塞进一个巨型提交，也不要把当前工作区所有文件一次性 `git add -A`。应逐项检查文件和差异，再按功能暂存。

Git 提交历史是日常同步的唯一事实来源。需要离线保存补丁时，再从已审查的提交导出 `git format-patch` 文件；不要同时对同一批修改执行“rebase 已含提交”和“重复 git am 补丁”，否则会重复应用。

## 5. 下一版一键脚本的执行流程

### 阶段 A：预检

- 确认运行位置是 Nexus 9 定制工具仓库或指定项目目录。
- 检查 Git、Java 17、Android SDK、Gradle 8.14.3。
- 检查上游远程和 `main` 分支存在。
- 读取定制提交清单，并确认它们基于记录的上游祖先。
- 不允许在用户现有的脏工作树中直接 rebase、reset 或覆盖文件。

### 阶段 B：创建隔离工作区

优先使用 Git worktree 或独立 clone，在单独路径创建本次构建工作区。先记录旧上游 SHA、最新上游 SHA、定制提交列表和构建目录。

如果使用临时 worktree：
- 从上游最新提交建立临时构建分支。
- 将定制提交按顺序重放到该分支。
- 为每次运行保留日志和恢复信息。
- 构建完成后只清理本次创建、且确认不再需要的临时目录；不清理用户已有目录。

### 阶段 C：同步与冲突处理

- 获取上游 `main` 最新提交。
- 在临时分支中重放定制提交。
- 冲突时停止，显示冲突文件和提交，不执行 `checkout --theirs`、`checkout --ours` 或强制重置。
- 人工解决后重新运行检查。
- 记录本次最终上游 SHA 和定制分支 SHA，方便复现。

### 阶段 D：静态检查

至少检查以下项目：

1. 评论/剧评/弹幕入口、专用网络实现、定时请求、覆盖层、测试和表情资源没有被上游重新引入。
2. 手机控制台、扫码遥控器和局域网控制服务没有被重新引入。
3. 桌面名称仍为 HGTV，applicationId 没有被意外改变。
4. 触摸焦点修复的目标文件和控件仍存在；若上游重构导致标记变化，停止并要求人工复核，不能只因旧字符串不存在就自动重写。
5. 播放器左右滑动 helper、事件安装点和状态保护条件仍存在。
6. 进度条、媒体按键、seek、EditText、选集、清晰度、音轨和播放恢复路径未被不相关地改写。
7. `git diff --check` 通过。

静态搜索只能作为回归哨兵，不等于运行时证明；每次上游结构变化后应检查实际代码上下文。

### 阶段 E：测试与构建

当前已验证通过的测试和构建命令为：

```bash
:app:testDebugUnitTest
:app:assembleDebug
```

执行环境记录：
- Ubuntu 24.04.4 LTS
- Java 17：`/usr/lib/jvm/java-17-openjdk-amd64`
- Android SDK：`$HOME/Android/Sdk`
- Gradle 8.14.3（当前成功构建使用已安装的 Gradle 8.14.3 发行版）

当前恢复工作区曾执行以下命令并成功：

```bash
cd "$HOME/hongguoTV-v0166-recovery/kotlin-tv"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
"$HOME/.gradle/wrapper/dists/gradle-8.14.3-bin/cv11ve7ro1n3o1j4so8xd9n66/gradle-8.14.3/bin/gradle" \
  :app:testDebugUnitTest :app:assembleDebug --no-daemon
```

记录到的结果：`BUILD SUCCESSFUL`，46 actionable tasks（9 executed、37 up-to-date）。本轮构建输出曾使用：

```text
app/build/outputs/apk/debug/app-debug.apk
```

构建脚本应从 Gradle 输出或构建目录中发现 APK，并确认只有一个符合目标变体的 APK；不要盲目假设旧脚本中的 `app/build/platform/outputs/apk/...` 路径在每个上游版本都有效。

### 阶段 F：APK 验证和归档

构建成功后自动输出：
- 上游提交 SHA。
- 定制提交 SHA 列表。
- 应用版本名/版本号及 applicationId。
- APK 路径、大小和 SHA-256。
- 单元测试与构建结果。
- 尚需在 Nexus 9 上人工回归的项目。

建议归档到独立目录，例如：

```text
dist/
  nexus9-hongguotv-<version>-<date>.apk
  nexus9-hongguotv-<version>-<date>.sha256
  nexus9-hongguotv-<version>-<date>.build-info.txt
```

默认只生成文件，不自动安装、不自动推送到 GitHub、不自动发布 Release。安装应由用户在确认构建结果后执行。

## 6. 每次构建后的 Nexus 9 回归清单

- [ ] 首页卡片、按钮第一次触摸即执行。
- [ ] 详情页按钮和选集按钮第一次触摸即执行。
- [ ] 播放设置按钮第一次触摸即执行。
- [ ] 左滑下一集、右滑上一集；边界集数不越界。
- [ ] 轻点视频区域切换完整播放菜单。
- [ ] 斜向滑动不会误切集。
- [ ] 菜单和子面板打开时不会误触发视频切集。
- [ ] 遥控器方向键仍移动焦点，确定键仍执行。
- [ ] D-pad 左右仍保持原快退/快进行为。
- [ ] 进度条拖动、选集、清晰度、音轨和播放恢复正常。
- [ ] 搜索框仍能输入和呼出软键盘。
- [ ] 评论、剧评、弹幕和手机控制入口/服务没有重新出现。

## 7. 当前现有脚本的能力边界

仓库现有的 `update_hgtv.sh` 是旧版同步构建脚本。它要求在 hongguoTV 源码仓库内运行，默认要求分支为 `hgtv-custom`，上游远程为 `origin/main`，工作区必须干净；之后建立备份分支、fast-forward/rebase、执行源码标记检查、部分测试并构建 APK。

它目前不负责：
- 从今天的本地恢复工作区自动提取和分类修改。
- 把尚未提交的文件自动转成独立定制提交。
- 在隔离 worktree 中生成全新构建环境。
- 自动解决上游冲突。
- 保证旧 APK 固定路径适用于所有上游版本。

因此，现有脚本可作为旧分支的同步构建工具，但不应被描述为已经具备本文件第 5 节全部能力的最终一键工具。下一版应先完成定制提交的分类和基线核验，再实现隔离 worktree 流程。

## 8. 迁移到真正一键化前的待办

- [ ] 盘点当前恢复工作区所有已修改、已删除和未跟踪文件；未知文件原样保留。
- [ ] 将弹幕/评论移除、触摸焦点、左右滑动等功能分别核对完整差异。
- [ ] 确认哪些改动已经存在于 `kotlin-v0.16.6` 基线、哪些是后续定制，避免重复应用。
- [ ] 按功能形成独立、可审查的 Git 提交。
- [ ] 记录每个提交对应的基线 SHA 和测试结果。
- [ ] 实现隔离 worktree 的 `nexus9-update-build.sh`。
- [ ] 在一次新的上游同步中验证冲突停止、检查、测试、APK 发现和 SHA-256 输出。
- [ ] Nexus 9 真机完成第 6 节回归后，才将该自动化版本标记为稳定。

## 9. 安全原则

- 不在未检查差异时执行 `git add -A`、`git reset --hard` 或强制覆盖。
- 不删除未知未跟踪文件，不自动清理用户工作区。
- 不把访问令牌、签名密钥、个人配置或 APK 构建产物放进源码补丁。
- 不推送上游仓库；本工具只维护个人定制副本。
- 每次更新必须记录来源提交、定制提交和构建摘要。
- 上游重构后若自动检查失效，停止并人工审查，不降低检查标准来“让脚本通过”。
