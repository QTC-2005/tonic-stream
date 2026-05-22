# Tonic Streaming Rebuild - 上下文保持文档

> **用途**：每次开始工作前先读这个文件，防止遗忘当前进度和关键上下文。
>
> 最后更新: 2026-05-22 (Phase 2 全部完成, 待推进 Phase 3)

---

## 已知问题
1. `shadcn_flutter: ^0.0.47` 不兼容当前 Flutter 3.41.8 — `NavigationLabel` 等 API 错误，需修复
2. `flutter_secure_storage_linux` 依赖指向 `m-berto/flutter_secure_storage.git#patch-2` 分支已被删除，已改为 `develop` 分支
3. drift migration tests (`test/drift/`) 需重新生成 schema — 当前 7 个 schema 文件与 model 不一致，flutter test 跳过
4. 构建依赖下载问题：`media_kit_libs_windows_audio` 需从 GitHub 下载 mpv-dev.7z，`sqlite3_flutter_libs` 需从 sqlite.org 下载源码，国内可能被墙/缓慢
5. 构建前需: 预下载 mpv-dev.7z (通过 gh-proxy.com) 到 `build/windows/x64/`；预先创建 `build/native_assets/windows/` 目录

## 设计待解决的问题

### 音质覆盖（用户关注：2026-05-22）

| 音源 | 当前取流策略 | 最大音质 | 问题 |
|------|-------------|---------|------|
| **QQ音乐** | sq > pq > hq > standard > fq 自动选优 | SQ 无损 | ✅ 已最优 |
| **酷我** | `level=zp`（指定无损） | ZP 无损 | ✅ 已最优 |
| **网易云** | meting API 默认返回 | 未知 | ⚠️ 未指定品质参数，可能返回低码率 |
| **咪咕** | API 默认返回 | 未知 | ⚠️ 未指定品质参数 |

### HTTP 延迟隐患（用户关注：2026-05-22）

- 当前 4 个音源搜索是串行的（SourceAggregator），4 次 HTTP GET = 4 倍最慢延迟
- 应该并发搜索 + 流式展示（先返回先显示）
- QQ/酷我/咪咕搜索 API 已返回封面/部分元数据，应预缓存减少二次请求
- 实际延迟取决于代理 API 服务器位置，需实测后才能确定瓶颈

---

## 注意事项

1. ⚠️ **不要动原 Tonic 项目**：`E:\Program Files\Musicplayer\tonic\` 是已完成的本地播放器，新项目在 `tonic-stream/`
2. ⚠️ **Spotube 是 BSD-4-Clause 开源协议**：可以商改，但需保留版权声明
3. ⚠️ **MusicFree 是 AGPL-3.0 协议**：引用其插件 API 设计时注意协议兼容性
4. ⚠️ **国内音源 API 可能不稳定**：需要多音源 fallback 机制
5. ⚠️ **Windows Unicode 路径问题**：原 Tonic 已解决（temp alias 方案），新项目可能也会遇到
6. ⚠️ **每次工作前读这个文件**，更新日期和进度

---

## 快速启动命令

```powershell
# 定位到项目
cd E:\Program Files\Musicplayer\tonic-stream

# 获取依赖
flutter pub get

# 分析
flutter analyze

# 测试
flutter test

# Windows debug 运行
flutter run -d windows

# Windows debug 构建
flutter build windows --debug
```

---

## 我们现在在做什么

用 **Spotube 5.1.1 (Flutter)** 作为基础框架，替换掉原来的 YouTube 音源，改造成：
- 支持中国国内音乐源（Bilibili、网易云音乐等）
- 品牌改为 **Tonic**（天蓝色主题）
- 继承原 Tonic 的本地播放能力
- 面向中国用户使用

## 为什么是 Spotube 而不是其他

| 候选 | 技术栈 | 结论 |
|------|--------|------|
| **Spotube** | Flutter/Dart, 插件化, 跨平台 | ✅ 基础框架 - UI/播放/队列/下载 都已完善 |
| MusicFreeDesktop | Electron/React | ❌ 不是 Flutter，太重 |
| NiuMa | Python/PyQt5 | ❌ 只有本地功能，无流媒体架构 |
| 原 Tonic | Flutter, 纯本地 | ⚠️ 没有在线音源架构 |

## 为什么不只是做插件

Spotube 的插件系统用 **Hetu Script**（小众脚本语言），生态很小，现有插件全是 YouTube 系的。在中国音源方面从零写 Hetu Script 插件不现实。

**我们的策略**：
1. 在 Dart 层实现音源引擎（绕过 Hetu Script 限制）
2. 保留 Hetu Script 插件系统作扩展能力
3. 优先实现 MusicFree JS 插件桥接层（复用已有生态）

---

## 关键文件路径

### 源项目文件
| 文件 | 描述 |
|------|------|
| `E:\Program Files\Musicplayer\spotube-5.1.1.zip` | Spotube 源码压缩包 (1363 files, 46MB) |
| `E:\Program Files\Musicplayer\MusicFree-master.zip` | MusicFree 移动端源码 |
| `E:\Program Files\Musicplayer\MusicFreeDesktop-master.zip` | MusicFree 桌面端源码 |
| `E:\Program Files\Musicplayer\NiuMa_Music_Player-main.zip` | 牛马播放器（B站搜索/下载逻辑） |

### 目标项目
| 路径 | 描述 |
|------|------|
| `E:\Program Files\Musicplayer\tonic\` | 原 Tonic 项目（本地播放器，Phase 5） |
| `E:\Program Files\Musicplayer\tonic-stream\` | **Tonic Streaming 项目（当前工作目录）** |

### 参考代码
| 路径 | 用途 |
|------|------|
| `NiuMa/tools/search_music.py` | B站搜索 + AI选歌逻辑 |
| `NiuMa/tools/auto_download_bilibili.py` | B站音频下载 |
| MusicFree Desktop 插件系统 | JS 插件 API 参考 |

---

## Spotube 架构速查

### 项目结构
```
lib/
  main.dart                    # 入口
  collections/                 # 路由、图标、常量
  components/                  # 通用 UI 组件
  hooks/                       # Flutter hooks
  models/
    metadata/
      audio_source.dart        # 音频源模型（StreamObject, MatchObject）
      plugin.dart              # 插件配置模型
  modules/                     # 功能模块
    metadata_plugins/          # 插件管理 UI
    library/                   # 本地库
    lyrics/                    # 歌词
  pages/                       # 页面
  provider/
    metadata_plugin/           # 插件 + 音源状态管理
      audio_source/            # 音源质量预设
  services/
    audio_services/            # 音频播放服务
```

### 插件格式 (.smplug)
- 实际是 zip 包，包含 `plugin.json` + `plugin.out` + `logo.png`
- `.out` 文件是编译后的 Hetu Script
- 插件类型：`metadata`（元数据） 和 `audio-source`（音频源）

### AudioSource 核心接口
```dart
// 搜索返回匹配列表
SpotubeAudioSourceMatchObject { id, title, artists, duration, thumbnail, externalUri }
// 获取播放流
SpotubeAudioSourceStreamObject { url, container, type, codec, bitrate, ... }
```

### 关键依赖
- `media_kit` - 音频/视频播放
- `hetu_script` - 插件脚本引擎
- `riverpod` - 状态管理
- `drift` - 本地数据库
- `dio` - HTTP 客户端
- `shadcn_flutter` - UI 组件库

---

## MusicFree 插件架构速查

- 插件是 **JavaScript** 文件
- 桌面版在 Electron 环境中运行
- 移动版在 React Native 中运行
- 插件实现搜索、获取流、获取歌词等接口
- 已有成熟的中国音源插件生态

### MusicFree 插件关键 API
- 搜索：`search(keyword, type, page)`
- 获取歌曲详情/播放地址
- 获取歌词
- 获取歌单

---

## 当前 Tonic (本地版) 有价值的东西

### 可以直接迁移到新项目
- 本地文件扫描 (`lib/services/scanner/`)
- NCM 解密 (`lib/services/decrypt/`)
- 播放器 UI 组件
- 天蓝色主题配色
- 中文化经验

### 不可以直接迁移的（要重新设计）
- `TrackPlayer` - 需要支持在线源
- `LibraryNotifier` - 需要合并在线+本地数据
- 播放队列逻辑 - 需要处理网络源

---

## 技术决策记录

| 日期 | 决策 | 原因 |
|------|------|------|
| 2026-05-22 | 选 Spotube 为基而不是 MusicFreeDesktop | MusicFreeDesktop 是 Electron (重), Spotube 是 Flutter (轻+性能好) |
| 2026-05-22 | 在 Dart 层实现音源，不用 Hetu Script | Hetu Script 生态太小，不值得投入 |
| 2026-05-22 | 优先做 MusicFree 插件桥接 | 复用现有中文插件生态，避免重复造轮子 |
| 2026-05-22 | 保留 Hetu Script 插件系统 | 未来社区可以贡献自己的音源插件 |

---

## 当前进度

| Phase | 状态 | 最后更新 |
|-------|------|----------|
| Phase 0 | ✅ 已完成 | 2026-05-22 |
| Phase 1 | ✅ 已完成 | 2026-05-22 |
| Phase 2 | ✅ 2.A+2.B+2.C+2.D 全部完成 | 2026-05-22 |
| Phase 3 | ⬜ 未开始 | - |
| Phase 4 | ⬜ 未开始 | - |
| Phase 5 | ⬜ 未开始 | - |

### 当前 Step
**Phase 2 全部完成！** 下一步 Phase 3 (品牌重塑)。

### Phase 2 进度
| Step | 状态 | 说明 |
|------|------|------|
| 2.A.1-2.A.5 | ✅ | 四大音源 + 注册, 32 tests |
| 2.B.1-2.B.3 | ✅ | B站增强, 14 tests |
| 2.C.1-2.C.4 | ✅ | MusicFree桥接原型, 8 tests |
| 2.C.5 | ✅ | 真实插件验证: axios+cheerio polyfill, async支持, 14 tests |
| 2.D.1-2.D.5 | ✅ | 并发搜索+延迟追踪+动态优先级+品质标签+缓存, 19 tests |
| 2.D.6-2.D.7 | 🟡 | 后端就绪 (userBoost/QualityTag), UI 配置界面留待 Phase 3 |
| **总计** | — | **97 tests pass, 0 analysis issues** |

### 2.D 新增能力
- **并发搜索**: `searchStreamed()` 所有音源同时发起，先返回先展示
- **延迟追踪**: `SourceEntry.recordLatency()` 滑动窗口 (10 samples)
- **动态排序**: 按 `sortScore = 平均延迟 + userBoost` 排序，快者优先
- **品质标签**: `QualityTag` (lossless/high/standard/unknown)，QQ音乐=high, 酷我=lossless
- **预缓存**: `TonicSourceMatch.cacheData` 承载搜索→getStreams 间数据，减少重复 API 调用

### MusicFree 桥接现状
- **已实现**: QuickJS CommonJS 沙箱, 同步+异步插件加载, 方法/属性调用, TonicAudioSource 适配器
- **Axios polyfill**: 基于 flutter_js XHR (Dart `http` 包), 支持 get/post/params/headers/timeout
- **Cheerio polyfill**: 纯 JS HTML 解析器 + jQuery 遍历 (children/first/find/text/attr/prop), 支持 tag/.class/#id/`>` 选择器
- **桩模块**: dayjs, qs, he, crypto-js, big-integer, webdav
- **已验证**: 真实 `geciqianxun` (歌词千寻) 插件 — 搜索/歌词获取 全链路通过
- **已知限制**:
  1. 国内网络限制导致一些歌词/音源站点不可达（非桥接问题）
  2. `quickjs_c_bridge.dll` 需手动部署到项目根目录 (test) 或构建输出 (app)
  3. cheerio polyfill 覆盖常用选择器，复杂 jQuery 选择器可能不兼容

> **策略变更** (2026-05-22)：发现 musicsquare 项目用纯 HTTP GET 调用代理 API 即可覆盖 QQ/网易云/酷我/咪咕四大音源，不需要 JS 引擎。
> 因此 Phase 2 改为：**主流音源直接用 Dart HTTP 实现**，MusicFree JS 桥接降为生态扩展（Phase 2.C，后续推进）。

### Phase 0 状态
| Step | 状态 |
|------|------|
| 0.1 解压 | ✅ |
| 0.2 重命名 | ✅ |
| 0.3 图标替换 | ✅ |
| 0.4 pubspec.yaml | ✅ |
| 0.5 清理无用代码 | ✅ |
| 0.6 验证构建 | ✅ |

### Phase 1 状态
| Step | 状态 | 关键产出 |
|------|------|---------|
| 1.1 研究音源路由 | ✅ | 分析了 quality_presets, audio_source, plugin_repository, metadata_plugin_provider |
| 1.2 设计接口 | ✅ | `TonicAudioSource`, `SourceAggregator`, `TonicSourceMatch/Stream`, `SourcePriority` |
| 1.3 实现 SourceRouter | ✅ | `SourceRouter`, `sourceRouterProvider`, `tonicSourceAggregatorProvider` |
| 1.4 Bilibili 引擎 | ✅ | `BilibiliAudioSource` — search (JSON API) + getStreams (DASH playurl) |
| 1.5 集成测试 | ✅ | 30 tests: models, aggregator routing, bilibili mock |

### Phase 1 关键文件
- `lib/core/source/tonic_audio_source.dart` — 抽象音源接口
- `lib/core/source/models.dart` — TonicSourceMatch, TonicSourceStream, SourcePriority
- `lib/core/source/source_aggregator.dart` — 多引擎聚合器 (含 Spotube 模型转换)
- `lib/core/source/source_router.dart` — 路由: 内置引擎 → Hetu 插件
- `lib/core/source/source_provider.dart` — Riverpod provider
- `lib/core/source/source.dart` — barrel export
