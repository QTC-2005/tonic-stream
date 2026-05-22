# Tonic Streaming Rebuild - 工作流

> 最终目标：基于 Spotube (Flutter) 复刻，替换为中文音源，打造 Tonic 在线音乐播放器。
>
> 创建日期: 2026-05-22 | 最后更新: 2026-05-22

---

## AI 技能速查

本项目集成了 Claude Code 技能系统。**用户只需说自然语言，AI 会自动匹配技能。**

| 你想做什么 | 说这句话就行 | AI 会触发 |
|-----------|-------------|----------|
| 开始一个大任务前讨论方案 | "先 brainstorm 一下" | `brainstorming` |
| 制定详细的执行计划 | "帮我写个计划" | `writing-plans` |
| 按计划分任务执行 | "开始执行计划" | `executing-plans` / `subagent-driven-development` |
| 多个独立任务并行 | "这几个可以并行做" | `dispatching-parallel-agents` |
| 需要先调研代码 | "研究一下这个模块" | `Explore` (子代理) |
| 修复 bug | "修一下这个 bug" | `systematic-debugging` |
| 完成一批工作后审查 | "帮我 review 一下" | `requesting-code-review` |
| 完成所有工作准备收尾 | "收尾" | `finishing-a-development-branch` |

> **用户不需要记技能名**，用自然语言描述需求就行。AI 根据当前正在做的 Step 自动调用合适的技能。

---

## 每次开始工作前

1. **阅读 `docs/CONTEXT.md`** 了解当前进度和关键技术上下文
2. **确认当前 Phase 和 Step** 知道从哪里继续
3. **AI 自动调用对应技能**：根据当前 Step 的任务类型，AI 会判断是否需要调用 brainstorming、writing-plans 等技能
4. **遵循工作规则**：每完成一个步骤 → 更新 WORKFLOW.md + CONTEXT.md → 提交验证 → 再进入下一步

---

## 总体阶段

| Phase | 名称 | 状态 | 推荐技能路径 |
|-------|------|------|-------------|
| **Phase 0** | 项目初始化（提取 + 重命名 + 构建验证） | 🟡 进行中 | 直接推进，无需技能 |
| **Phase 1** | 音源架构改造（Dart 层音源引擎设计） | ⬜ 待开始 | `brainstorming` → `writing-plans` → `subagent-driven-development` |
| **Phase 2** | 中国音源实现（Bilibili + MusicFree 桥接） | ⬜ 待开始 | `writing-plans` → `dispatching-parallel-agents` |
| **Phase 3** | 品牌重塑（名称/图标/配色 → Tonic） | ⬜ 待开始 | 直接推进或 `dispatching-parallel-agents` |
| **Phase 4** | 功能整合（原 Tonic 本地播放能力合并） | ⬜ 待开始 | `writing-plans` → `subagent-driven-development` |
| **Phase 5** | 构建与发布（Windows 构建/安装包/文档） | ⬜ 待开始 | 直接推进 |

---

## Phase 0: 项目初始化

**目标**：提取 Spotube → 重命名 → 能在 Windows 上跑起来。

- [x] **Step 0.1**: 解压 Spotube 到 `tonic-stream/` 目录 ✅
- [x] **Step 0.2**: 全局重命名 `spotube` → `tonic` ✅
  - `pubspec.yaml` name/description/version/homepage ✅
  - 全局 Dart 文件 `package:spotube/` → `package:tonic/` ✅
  - Android: `build.gradle` (namespace, applicationId), Kotlin 包路径 ✅
  - Windows: `Runner.rc` (FileDescription, InternalName, ProductName), `main.cpp` ✅
  - iOS: Info.plist, entitlements, bundle identifiers ✅
  - Web: `manifest.json`, `index.html` ✅
  - macOS: `AppInfo.xcconfig` ✅
- [x] **Step 0.3**: 替换应用图标 ✅
  - 从原 Tonic 项目提取天蓝色音符图标 ✅
  - 生成所有格式的 Tonic 品牌图标(1024px PNG, 48px ICO, 55px BMP, Android 自适应, macOS, 等) ✅
  - 替换 `assets/branding/` 下所有 spotube-logo* 为 tonic-logo* ✅
  - 删除 spotube-nightly 品牌资源 ✅
  - 更新 `flutter_launcher_icons.yaml` 路径引用 ✅
  - 更新 `pubspec.yaml` assets 路径和 native_splash 路径 ✅
  - 更新 `tray_manager.dart` 托盘图标路径 ✅
  - 更新 `discord_provider.dart` Discord RPC 图标键名 ✅
  - 更新 `assets.gen.dart` 生成图标常量 ✅
  - 更新 `greeting.dart` 和 `about.dart` 品牌图片引用 ✅
- [x] **Step 0.4**: 更新 `pubspec.yaml` ✅
  - version: `0.1.0+1`
  - homepage/repository
- [x] **Step 0.5**: 删除不需要的代码 ✅
  - 删除 Spotify SSL 证书绕过 (`http-override.dart`) 及 main.dart 中的引用 ✅
  - 删除已完全注释的死代码 (`quickjs_solver.dart`) ✅
  - 更新更新检查 URL 从 `KRTirtho/spotube` 指向 `tonic-player/tonic` ✅
- [ ] **Step 0.6**: 验证构建
  - `dart analyze lib/` — **通过** (0 errors, 294 pre-existing warnings/info) ✅
  - `flutter pub get` — 需在 Windows 原生环境运行 (MSYS2 缺少 System32 PATH)
  - `flutter analyze` — 需在 Windows 原生环境运行
  - `flutter test` — 需在 Windows 原生环境运行
  - `flutter build windows --debug` — 需在 Windows 原生环境运行

### Phase 0 验证方法
```powershell
cd E:\Program Files\Musicplayer\tonic-stream
flutter pub get
flutter analyze
flutter test
flutter build windows --debug
```

---

## Phase 1: 音源架构改造

**目标**：在 Dart 层设计统一音源接口，可以接入多种中文音源。

> **AI 工作流**：进入 Phase 1 时，先调用 `brainstorming` 技能讨论音源接口设计方案，再用 `writing-plans` 制定详细执行计划，然后按计划推进。

- [ ] **Step 1.1**: 研究 Spotube 现有音源路由逻辑
  - `lib/provider/metadata_plugin/audio_source/quality_presets.dart`
  - `lib/models/metadata/audio_source.dart`
  - `lib/modules/metadata_plugins/plugin_repository.dart`
  - `lib/provider/metadata_plugin/metadata_plugin_provider.dart`
  - **AI**: 调用 Explore 子代理研究这些文件结构
- [ ] **Step 1.2**: 设计 Tonic Audio Engine 接口
  - `AudioSource` 抽象类：search / getStream / getLyrics
  - `MetadataSource` 抽象类：getAlbum / getArtist / searchSuggestions
  - `SourceAggregator`：聚合多个音源结果
  - **AI**: 用 `writing-plans` 制定接口设计计划
- [ ] **Step 1.3**: 实现 SourceRouter（从内置 Dart 源 + Hetu 插件联合获取）
- [ ] **Step 1.4**: 实现 Bilibili 音源引擎原型
  - 搜索 API 调用
  - 音频流提取
- [ ] **Step 1.5**: 写集成测试验证多音源路由

### Phase 1 关键文件
- 音源引擎: `lib/services/sources/`
- 音源接口: `lib/core/source/`

---

## Phase 2: 中国音源实现

**目标**：接入 Bilibili 音源 + MusicFree 插件生态桥接。

> **AI 工作流**：Bilibili 和 MusicFree 是两个独立子系统，进入 Phase 2 时调用 `dispatching-parallel-agents` 并行推进。

### 2.A Bilibili 音源
- [ ] B站搜索（参考 NiuMa 的 `tools/search_music.py`）
- [ ] 音频流 URL 提取（从 B站视频提取音频）
- [ ] 元数据解析（歌手、封面、歌词）

### 2.B MusicFree 插件桥接层（高优先级）
- [ ] 调研 `flutter_js` 或 QuickJS 嵌入方案
- [ ] 实现 MusicFree 插件 API 兼容层
- [ ] 插件热加载管理 UI
- [ ] 验证网易云音乐插件可运行

### Phase 2 验证方法
- 搜索测试（用中文歌名搜索，返回结果）
- 播放测试（获取音频流并播放）
- 插件桥接测试（加载 MusicFree 插件，执行搜索）

---

## Phase 3: 品牌重塑

**目标**：所有地方都是 Tonic。

> **AI 工作流**：多个独立任务可并行，调用 `dispatching-parallel-agents` 同时推进文案替换、图标、配色、启动画面。

- [ ] **Step 3.1**: 全局文案替换
- [ ] **Step 3.2**: 图标：天蓝色 Tonic 图标（继承现有 Tonic 图标）
- [ ] **Step 3.3**: 配色：sky blue 主题
- [ ] **Step 3.4**: 启动画面
- [ ] **Step 3.5**: 关于页面
- [ ] **Step 3.6**: 清理所有 Spotify/YouTube 残余引用

---

## Phase 4: 功能整合

**目标**：把原 Tonic 的本地播放能力合并进来。

> **AI 工作流**：进入 Phase 4 时调用 `writing-plans` 制定合并方案，评估原 Tonic 模块与 Spotube 现有架构的兼容性。

- [ ] 本地文件夹扫描
- [ ] NCM 解密导入
- [ ] 本地播放列表
- [ ] 统一播放队列（在线 + 本地）
- [ ] 缓存管理

---

## Phase 5: 构建与发布

- [ ] Windows release 构建
- [ ] 安装包（Inno Setup）
- [ ] 使用文档
- [ ] 音源配置指南
- [ ] **最后一步**：调用 `finishing-a-development-branch` 收尾

---

## 工作规则

1. **每步验证**：每完成一个 Step 就运行 `flutter analyze` + `flutter test`，不堆积问题
2. **提交证据**：关键验证结果保存到 `verification-logs/`
3. **更新文档**：每次代码变更后更新 `WORKFLOW.md` 和 `CONTEXT.md`
4. **不跳步**：Phase 之间有依赖，确保前一步完成再进入下一步
5. **参考已有代码**：NiuMa 的 B站搜索逻辑、MusicFree 的插件 API 规范
6. **保持构建可用**：不要在 broken build 上继续开发
7. **AI 技能自动匹配**：AI 根据任务类型自动调用合适的技能，用户只需自然语言描述需求

---

## 快速命令参考（给用户）

如果你的 AI 助手行为异常或你想手动触发某个技能，可以说：

| 命令 | 效果 |
|------|------|
| `/brainstorming` 我想讨论 Phase 1 的方案 | 触发头脑风暴 |
| `/writing-plans` 帮我制定 Bilibili 音源的计划 | 生成计划文档 |
| `/execute-plans` | 执行已有计划 |
| 用子代理执行计划 | 分任务独立执行 |
| 这几个任务并行做 | 多代理并行 |

**日常开发直接说需求就行，不用特意提技能名。**

---

## 更新日志

| 日期 | 更新 |
|------|------|
| 2026-05-22 | 初始化工作流文档，制定 Phase 0-5 计划 |
| 2026-05-22 | 集成 AI 技能调用引导，Step 0.1-0.2 完成 |
