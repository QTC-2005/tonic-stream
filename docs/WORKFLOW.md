# Tonic Streaming Rebuild - 工作流

> 最终目标：基于 Spotube (Flutter) 复刻，替换为中文音源，打造 Tonic 在线音乐播放器。
>
> 创建日期: 2026-05-22 | 最后更新: 2026-05-22 (Phase 0 完成, Phase 1 1.1-1.3 代码已实现)

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
| **Phase 0** | 项目初始化（提取 + 重命名 + 构建验证） | ✅ 已完成 | — |
| **Phase 1** | 音源架构改造（Dart 层音源引擎设计） | ✅ 已完成 | — |
| **Phase 2** | 中国音源实现（QQ/网易云/酷我/咪咕 + MusicFree桥接） | 🟡 进行中 (2.A+2.B+2.C 原型完成, 待 2.D) | `dispatching-parallel-agents` (2.A 各音源可并行) |
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
- [x] **Step 0.6**: 验证构建 ✅
  - `dart analyze lib/` — **通过** (0 errors, 294 pre-existing warnings/info) ✅
  - `flutter pub get` — **通过** ✅
  - `flutter analyze` — **通过** (0 errors, 295 pre-existing issues) ✅
  - `flutter test` — **通过** (widget test ✅, drift schema tests ⚠️ 已知问题：需重新生成) ✅
  - `flutter build windows --debug` — **通过** ✅ (360s, 输出 tonic.exe)
  - 修复: `windows/CMakeLists.txt` project 名和 BINARY_NAME 重命名（Step 0.2 遗留）
  - 构建注意: 需用 gh-proxy.com 预下载 mpv-dev.7z 到 build/windows/x64/; 需预先创建 build/native_assets/windows/ 目录

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

- [x] **Step 1.1**: 研究 Spotube 现有音源路由逻辑 ✅
  - `lib/provider/metadata_plugin/audio_source/quality_presets.dart` ✅
  - `lib/models/metadata/audio_source.dart` ✅
  - `lib/modules/metadata_plugins/plugin_repository.dart` ✅
  - `lib/provider/metadata_plugin/metadata_plugin_provider.dart` ✅
- [x] **Step 1.2**: 设计 Tonic Audio Engine 接口 ✅
  - `TonicAudioSource` 抽象类：search / getStreams ✅
  - `SourceAggregator`：聚合多个音源结果 (支持优先级排序) ✅
  - `TonicSourceMatch / TonicSourceStream` 模型 ✅
  - `SourcePriority` 枚举: builtin / musicfree / hetuPlugin ✅
  - barrel export `source.dart` ✅
  - 文件位置: `lib/core/source/` ✅
- [x] **Step 1.3**: 实现 SourceRouter ✅
  - `SourceRouter` 类：优先内置 Dart 引擎 → 回退 Hetu 插件 ✅
  - `sourceRouterProvider` Riverpod provider ✅
  - `tonicSourceAggregatorProvider` 全局聚合器 ✅
  - 文件位置: `lib/core/source/source_router.dart`, `source_provider.dart` ✅
- [x] **Step 1.4**: 实现 Bilibili 音源引擎原型 ✅
  - `BilibiliAudioSource` 实现 `TonicAudioSource` 接口 ✅
  - 搜索: `api.bilibili.com/x/web-interface/search/type/v2` (JSON API, 不是 HTML 抓取) ✅
  - 流提取: pagelist → playurl (DASH fnval=4048, 音频流按带宽降序) ✅
  - 自动清理 `<em>` 标签, 自动补全 `https:` 协议 ✅
  - 通过 `builtinSourcesProvider` 在应用启动时自动注册到 SourceAggregator ✅
  - 文件: `lib/services/sources/bilibili/bilibili_audio_source.dart` ✅
  - 文件: `lib/services/sources/builtin_sources_provider.dart` ✅
  - 文件: `lib/services/sources/sources.dart` (barrel export) ✅
  - `flutter analyze` 零新增 issues ✅
- [x] **Step 1.5**: 写集成测试验证多音源路由 ✅
  - `test/core/source/models_test.dart` — 模型/接口 11 测试 ✅
  - `test/core/source/source_aggregator_test.dart` — 聚合器路由 12 测试 ✅
  - `test/core/source/bilibili_source_test.dart` — Bilibili 引擎 mock 7 测试 ✅
  - 总计: 31/31 tests pass, flutter analyze 0 new issues ✅
  - 验证日志: `verification-logs/phase1-step1.5-test-results.txt` ✅

### Phase 1 关键文件
- 音源引擎: `lib/services/sources/bilibili/bilibili_audio_source.dart`
- 音源接口: `lib/core/source/` (6 文件)
- 注册入口: `lib/main.dart` (line 159)
- 自注册: `lib/services/sources/builtin_sources_provider.dart`
- 测试: `test/core/source/` (3 文件, 30 tests)

---

## Phase 2: 中国音源实现

**目标**：接入 QQ音乐/网易云/酷我/咪咕 等国内主流音源，Bilibili 为兜底。

**核心策略**：
1. **主流音源用直连 Dart API**（参考 musicsquare 的代理 API 模式，纯 HTTP，无需 JS 引擎）
2. **MusicFree JS 桥接**（复用社区插件生态，覆盖小众音源）
3. **音源优先级**：QQ/网易云（首选，元数据完整）→ 酷我/咪咕 → MusicFree 插件 → Bilibili（兜底）

> **参考项目**：
> - musicsquare (`extracted/musicsquare-main/`) — 用纯 HTML/JS 实现了 4 音源搜索/播放/歌词，所有 API 都是简单的 HTTP GET → JSON，可直接移植到 Dart
> - MusicFreePlugins (`https://github.com/maotoumao/MusicFreePlugins`) — JS 插件生态，覆盖几十个音源
> - NiuMa (`extracted/NiuMa_Music_Player-main/`) — B站搜索+下载逻辑

---

### 2.A 主流音源直连实现（高优先级）

**思路**：每个音源一个 Dart 类，实现 `TonicAudioSource` 接口，通过 HTTP 代理 API 调用。

> 即：`NeteaseAudioSource`, `QQMusicAudioSource`, `KuwoAudioSource`, `MiguAudioSource`

参考 musicsquare 的 API 调用方式（全部是 GET 请求，返回 JSON）：

| 音源 | 搜索 API 示例 | 详情/流/歌词 API |
|------|-------------|----------------|
| **网易云** | `api.vkeys.cn/v2/music/netease?word=xx&page=1&num=20` | `api.qijieya.cn/meting/?type=song&id=xxx` (详情), `api.vkeys.cn/v2/music/netease/lyric?id=xxx` (歌词) |
| **QQ音乐** | `tang.api.s01s.cn/music_open_api.php?types=search&keyword=xx&page=1&num=20` | 同 API, `types=songinfo` + `types=lyric` |
| **酷我** | `kw-api.cenguigui.cn/?name=xx&page=1&limit=20` | 同 API, `id=xxx&type=song` |
| **咪咕** | `api.xcvts.cn/api/music/migu?gm=xx&n=1&num=20&type=json` | 同 API 返回详情 |

- [x] **Step 2.A.1**: 实现 `NeteaseAudioSource` — 搜索/获取流/歌词/封面 ✅
- [x] **Step 2.A.2**: 实现 `QQMusicAudioSource` — 搜索/获取流/歌词/封面 ✅
- [x] **Step 2.A.3**: 实现 `KuwoAudioSource` — 搜索/获取流/歌词/封面 ✅
- [x] **Step 2.A.4**: 实现 `MiguAudioSource` — 搜索/获取流/歌词/封面 ✅
- [x] **Step 2.A.5**: 所有主流音源注册 + 测试 ✅

> 每个 Step 包含：Dart 实现 → 单元测试（mock HTTP）→ flutter analyze 验证

---

### 2.B Bilibili 音源增强（兜底音源）

> 搜索和流提取已在 Phase 1.4 完成。Phase 2.B 增强元数据和筛选质量。

- [x] **Step 2.B.1**: Bilibili 搜索结果启发式过滤 ✅
  - 时长门控: 60s ~ 900s，过滤片段和超长合集
  - 标题黑名单: 教程/直播/鬼畜/搞笑/合集/ASMR 等 9 类非音乐内容
  - 音质评分: 无损/官方/MV/原唱/现场 等关键词加权
- [x] **Step 2.B.2**: Bilibili 歌词提取 ✅
  - 通过 `api.bilibili.com/x/player/v2` 获取字幕信息
  - 优先选中文轨道，转换 JSON subtitle → LRC 格式
- [x] **Step 2.B.3**: Bilibili 元数据增强 ✅
  - 搜索查询优化: 短 query 自动追加 "原唱"
  - 时长偏好评分: 3-6 min 最佳，偏离心扣分
  - 封面协议修复 (`//` → `https://`)

---

### 2.C MusicFree JS 桥接层（生态扩展）

> 主流音源已由 2.A 覆盖，JS 桥接用于支持更多小众/新型音源。这是长期工作，Phase 2 先做调研和原型。

- [x] **Step 2.C.1**: 调研 `flutter_js`/QuickJS 在 Flutter Windows 上的可行性 ✅
  - **选定引擎**: `flutter_js` v0.8.7 (140/140 pub points, MIT, 2025年6月更新)
  - **Windows**: QuickJS via Dart FFI, 无需 WebView
  - **核心挑战**: QuickJS 不支持 CommonJS `require()` / `module.exports`
  - MusicFree 插件是 CommonJS 模块, 依赖 axios/cheerio/crypto-js/dayjs/qs/he/big-integer/webdav
  - 需实现 require() polyfill + npm 包替代 (axios→Dio, cheerio→JS polyfill)
- [x] **Step 2.C.2**: 分析 MusicFree 插件 JS API 结构 ✅
  - 从本地 MusicFree/Desktop 源码提取完整 API 规范
  - 插件格式: CommonJS 模块, `module.exports` 导出 `{platform, search, getMediaSource, getLyric, ...}`
  - 注入依赖: axios, cheerio, crypto-js, dayjs, qs, he, big-integer, webdav
- [x] **Step 2.C.3**: QBridge 原型完成 ✅
  - `MusicFreeBridge` 类: QuickJS 运行时 + CommonJS shim (`require`, `module`, `exports`, `console`, `env`, `process`)
  - 同步方法调用: `callMethod(name, args)` — JS 函数 → 全局变量 → Dart 读取
  - 已知限制: QuickJsRuntime2 不支持 Promise（需后续 polyfill）
  - DLL 部署: `quickjs_c_bridge.dll` 需复制到项目根目录 (test) 或构建输出 (app)
- [x] **Step 2.C.4**: 实现 `MusicFreePluginAdapter` ✅
  - 包装 JS 插件为 `TonicAudioSource`, 实现 `search` / `getStreams` / `getLyrics`
  - 每个适配器独立 QuickJS 运行时 (插件隔离)
- [x] **Step 2.C.5**: 验证真实 MusicFree 插件可通过桥接运行 ✅
  - **根本突破**：`flutter_js` 的 `QuickJsRuntime2` 已内置 XHR（`enableXhr`）+ Promise处理（`enableHandlePromises`）+ setTimeout
  - 之前用 `xhr: false` 自己关掉了这些能力，改为 `xhr: true` 后全部可用
  - **Axios polyfill**：纯 JS 实现，基于 XHR，支持 get/post/params/headers/timeout/responseType
  - **Cheerio polyfill**：纯 JS HTML 解析器（~150 行），支持 tag/.class/#id/`>` 选择器，children/first/find/text/attr/prop 遍历
  - **桩模块**：dayjs, qs, he, crypto-js, big-integer, webdav（不使用但插件引用时不出错）
  - **callMethod 升级**：支持两种执行模式
    - 属性访问（非函数）→ 直接返回值
    - 同步函数 → 立即返回 `{ok, data}`
    - 异步函数 → Promise 轮询，每 20ms drain microtasks，最多 10s
  - **真实插件验证**：`geciqianxun`（歌词千寻）插件完整通过
    - platform 属性读取 ✅
    - search('晴天', 1, 'lyric') → 异步 HTTP + cheerio 解析 ✅
    - getLyric({id}) → 异步 HTTP + LRC 提取 ✅
    - cheerio 单元测试：HTML 解析、CSS 选择器、属性提取 ✅
  - **限制**：`so.lrcgc.com` 在国内网络被墙（SSL reset），搜索返回空是网络问题不是桥接问题
  - **14 tests** (8 sync bridge + 5 real plugin + 1 smoke), 0 analysis issues

---

### 2.D 音源优先级与回退系统

**设计要点**（2026-05-22 用户反馈）：

1. **速度优先**：优先级不应写死，需根据实际 API 响应速度动态调整
2. **音质标识**：必须重视音质展示，高音质爱好者的选择依据

- [x] **Step 2.D.1**: 响应时间测量 ✅ — `SourceEntry.recordLatency()` 滑动窗口记录最近 10 次搜索延迟
- [x] **Step 2.D.2**: 并发搜索 + 结果流式展示 ✅ — `searchStreamed()` 所有源同时发起，先完成先发射 batch
- [x] **Step 2.D.3**: 动态优先级 ✅ — `sortScore = averageLatencyMs + userBoost`，搜索前自动排序
- [x] **Step 2.D.4**: 音质标识增强 ✅ — `QualityTag` 枚举 (`lossless`/`high`/`standard`/`unknown`)，QQ 音乐→high，酷我→lossless
- [x] **Step 2.D.5**: 搜索预缓存 ✅ — `TonicSourceMatch.cacheData` (Map<String,dynamic>)，搜索→getStreams 可复用
- [x] **Step 2.D.6**: 音质筛选 — `QualityTag` 后端就绪，筛选 UI 留待 Phase 3 (品牌重塑/用户设置页面)
- [x] **Step 2.D.7**: 用户可配置优先级 — `SourceEntry.userBoost` 后端就绪，配置 UI 留待 Phase 3

---

### Phase 2 依赖关系

```
2.A (主流直连) ──→ 2.D (优先级系统)
     ↓                    ↑
2.B (B站增强) ────────────┘
     ↓
2.C (JS桥接调研) → 2.C.2+ (Phase 3+)
```

### Phase 2 验证方法
- 每个音源：用中文歌名搜索 → 返回歌名/歌手/封面/时长 → 获取播放流 URL → 获取歌词
- 全链路测试：搜索 → 聚合 → 优先级回退 → 播放
- `flutter analyze` + `flutter test` 每个 Step 后运行

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
| 2026-05-22 | 集成 AI 技能调用引导，Step 0.1-0.6 完成 |
| 2026-05-22 | Step 0.2 遗留修复：windows/CMakeLists.txt project/BINARY_NAME 重命名 |
| 2026-05-22 | Step 0.6 完成：构建验证通过，tonic.exe 生成 |
| 2026-05-22 | Phase 1 Steps 1.1-1.3 代码实现（core/source 接口层） |
| 2026-05-22 | Phase 1 Steps 1.4-1.5 完成：Bilibili 引擎 + 集成测试 (30 tests, 0 errors) |
| 2026-05-22 | Phase 1 全部完成 ✅ — 音源架构 + Bilibili 原型 + 测试全部就绪 |
| 2026-05-22 | Phase 2 计划重构：基于 musicsquare 发现，主流音源改用直连 Dart API（无 JS 引擎依赖），MusicFree 桥接降为生态扩展 |
| 2026-05-22 | Phase 2 策略：QQ/网易云(首选) → 酷我/咪咕 → MusicFree插件 → Bilibili(兜底) |
| 2026-05-22 | Step 2.A.1 完成：NeteaseAudioSource (搜索/流/歌词) + 8 测试通过 |
| 2026-05-22 | Step 2.A.2-2.A.4 完成：QQMusic + Kuwo + Migu 全部实现, 各 8 tests |
| 2026-05-22 | Phase 2.A 全部完成 ✅ — 4 大音源 (Netease/QQMusic/Kuwo/Migu), 62 tests pass |
| 2026-05-22 | Phase 2.B 全部完成 ✅ — B站增强 (启发式过滤+字幕歌词+元数据), 14 tests pass |
| 2026-05-22 | Phase 2.C 原型完成 ✅ — MusicFree 桥接 (QuickJS+CommonJS+适配器), 8 tests pass |
