# TOCK - tomato clock 番茄钟

[中文](#中文) | [English](#english)

## 中文

TOCK 是一款简约的 macOS 番茄钟应用，目标是提供快速、安静、符合 Mac 使用习惯的专注体验。

它目前是一个本地优先的早期 MVP，主要为个人日常使用而开发，同时也适合分享给喜欢轻量桌面工具的用户参考。

### 当前功能

- 支持倒计时和正计时专注
- 可直接修改默认专注时长和休息时长
- 倒计时结束后自动进入额外正计时
- 专注结束后手动进入休息
- 菜单栏显示计时，并支持隐藏为 Logo
- 支持系统通知开关
- 支持任务与分类管理
- 每个分类可设置颜色，并在任务和统计中复用
- 数据本地保存在 Application Support
- 支持今日任务时长自动跨天重置
- 支持日、周、月、年统计视图

### 本地运行

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift run --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

### 构建

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift build --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

### 打包为本地 macOS App

```sh
scripts/package_app.sh
open dist/TOCK.app
```

Release 构建：

```sh
scripts/package_app.sh release
open dist/TOCK.app
```

打包脚本会在 `dist/TOCK.app` 生成本地 App 包。

### 测试

```sh
scripts/smoke_test.sh
```

该脚本会构建并打包应用，然后检查 `dist/TOCK.app` 是否具备预期的 App Bundle 结构。

如果只想运行计时规则检查：

```sh
scripts/check_timer_engine.sh
```

GitHub Actions 会在 macOS 环境中运行同样的 smoke test。

### 产品文档

产品方向记录在 [PRD.md](PRD.md)。
线框图和视觉决策记录在 [WIREFRAMES.md](WIREFRAMES.md)。
实现结构记录在 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

### 下一步

- 生成生产可用的 `.icns` 应用图标
- 在适合公开分发时，加入签名和 notarization 流程

## English

TOCK is a minimal macOS Pomodoro app focused on fast, calm, native-feeling focus sessions.

It is currently an early local-first MVP, built primarily for personal daily use while staying suitable for sharing with people who enjoy lightweight desktop tools.

### Current Features

- Focus timer with countdown and count-up modes
- Editable default focus and break duration
- Overtime after countdown reaches zero
- Manual transition from focus to break
- Menu bar timer with hide/show option
- System notification toggle
- Task and category management
- Category colors used across tasks and statistics
- Local persistence in Application Support
- Daily rollover for today's task duration
- Statistics for day, week, month, and year

### Run Locally

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift run --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

### Build

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift build --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

### Package as a Local macOS App

```sh
scripts/package_app.sh
open dist/TOCK.app
```

For a release build:

```sh
scripts/package_app.sh release
open dist/TOCK.app
```

The package script creates a local app bundle at `dist/TOCK.app`.

### Smoke Test

```sh
scripts/smoke_test.sh
```

This builds and packages the app, then checks that `dist/TOCK.app` has the expected bundle structure.

To run only the deterministic timer-rule checks:

```sh
scripts/check_timer_engine.sh
```

The GitHub Actions workflow runs the same smoke test on macOS.

### Product Notes

The product direction is documented in [PRD.md](PRD.md).
Wireframes and visual decisions are documented in [WIREFRAMES.md](WIREFRAMES.md).
The implementation structure is documented in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Next Priorities

- Generate a production `.icns` app icon from `Assets/TOCK.svg`
- Add a signed and notarized release workflow when the app is ready to share outside local use
