# TOCK Implementation Plan

版本：v0.1
日期：2026-07-10
状态：MVP 实现准备

## 1. 技术选型

首版采用原生 macOS 技术栈：
- SwiftUI：主界面、页面布局、状态绑定
- AppKit NSStatusItem：菜单栏计时入口
- UserNotifications：系统通知
- SwiftData 或本地 JSON/SQLite：任务、分类、专注记录持久化

当前本机只有 Command Line Tools，暂时先用 Swift Package 初始化项目骨架。后续如果需要完整 Xcode 工程，可在安装完整 Xcode 后迁移或直接用 Xcode 打开 Package。

## 2. MVP 开发阶段

### Phase 1：项目骨架
- 初始化 SwiftUI macOS App
- 固定主窗口默认宽度 800px
- 搭建左侧导航：专注 / 统计 / 任务
- 搭建菜单栏入口

### Phase 2：专注计时
- 倒计时与正计时模式
- 专注时长与休息时长可编辑
- 任务绑定与分类选择
- 暂停、继续、结束
- 倒计时结束后切换为正计时，并等待用户进入休息

### Phase 3：任务与分类
- 分类列表与颜色
- 任务列表按分类分组
- 任务编辑态
- 新建任务、新建分类、归档任务

### Phase 4：统计
- 今日概览
- 近 30 天 10x3 热力图
- 今日任务占比
- 今日小时分布
- 日 / 周 / 月 / 年切换
- 分类筛选

### Phase 5：系统体验
- 系统通知
- 菜单栏时间显示 / 隐藏
- 主窗口关闭或隐藏后计时继续
- 基础设置入口

## 3. 数据模型草案

### Category
- id
- name
- color
- createdAt
- updatedAt

### Task
- id
- name
- categoryId
- isArchived
- createdAt
- updatedAt
- lastUsedAt

### FocusSession
- id
- taskId
- categoryId
- mode：countdown / countup
- startedAt
- endedAt
- focusedDuration
- pausedDuration
- plannedFocusDuration
- plannedBreakDuration

## 4. 当前已生成设计稿

- `mockups/focus-page-v0.4.svg`
- `mockups/statistics-page-v0.4.svg`
- `mockups/tasks-page-v0.1.svg`
- `mockups/tasks-page-edit-v0.1.svg`
- `mockups/menu-bar-states-v0.1.svg`

## 5. 下一步

先完成一个可运行的静态 UI 骨架，再逐步接入真实计时逻辑和本地数据持久化。

## 6. 本地构建

当前环境可以使用 SwiftPM 构建：

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache" swift build --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

说明：
- 当前机器未配置完整 Xcode，`xcodebuild` 暂不可用
- 上述命令已在当前环境构建通过
