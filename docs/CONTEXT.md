# Tonic Streaming Rebuild - 上下文保持文档

> **用途**：每次开始工作前先读这个文件，防止遗忘当前进度和关键上下文。
>
> 最后更新: 2026-05-22

---

## 已知问题
1. `shadcn_flutter: ^0.0.47` 不兼容当前 Flutter 3.41.8 — `NavigationLabel` 等 API 错误，需修复
2. `flutter_secure_storage_linux` 依赖指向 `m-berto/flutter_secure_storage.git#patch-2` 分支已被删除，已改为 `develop` 分支

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
| `E:\Program Files\Musicplayer\tonic-stream\` | **新** Tonic Streaming 项目（尚未创建） |

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
| Phase 0 | 🟡 Step 0.3 完成 | 2026-05-22 |
| Phase 1 | ⬜ 未开始 | - |
| Phase 2 | ⬜ 未开始 | - |
| Phase 3 | ⬜ 未开始 | - |
| Phase 4 | ⬜ 未开始 | - |
| Phase 5 | ⬜ 未开始 | - |

### 当前 Step
**Phase 0 Step 0.6**: 验证构建（需在 Windows 原生环境运行）

### Phase 0 状态
| Step | 状态 |
|------|------|
| 0.1 解压 | ✅ |
| 0.2 重命名 | ✅ |
| 0.3 图标替换 | ✅ |
| 0.4 pubspec.yaml | ✅ |
| 0.5 清理无用代码 | ✅ |
| 0.6 验证构建 | ⬜ 待运行 |
