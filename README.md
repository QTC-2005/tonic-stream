<div align="center">

# 🎵 Tonic

轻量级、跨平台音乐流媒体客户端，支持中文音源。

基于 Flutter 构建，融合本地播放与在线流媒体。

</div>

---

## ✨ 特性

- 🇨🇳 **中文音源支持** — QQ音乐 / 网易云音乐 / 酷我 / 咪咕 / Bilibili
- 🔌 **MusicFree 插件桥接** — 兼容 JS 插件生态，扩展更多音源
- ⚡ **并发搜索** — 多音源同时搜索，先返回先展示
- 🎧 **高品质音频** — 酷我无损 (FLAC) / QQ音乐 SQ / 320kbps 高码率
- 🎯 **动态优先级** — 根据历史响应速度自动排序，快源优先
- 📝 **同步歌词** — 从各平台获取歌词，支持 LRC 格式
- 🖥️ **跨平台** — Windows / macOS / Linux / Android / iOS
- 🪶 **轻量原生** — Flutter 构建，非 Electron 套壳
- 🔒 **隐私优先** — 无遥测、无诊断报告、无用户数据收集
- 📖 **开源自由** — BSD-4-Clause 协议

---

## 🇨🇳 音源支持

| 音源 | 搜索 | 高品质 | 歌词 | 备注 |
|------|:----:|:------:|:----:|------|
| **网易云音乐** | ✅ | — | ✅ | meting API |
| **QQ音乐** | ✅ | SQ 无损 | ✅ | 多品质自动选优 |
| **酷我音乐** | ✅ | ZP 无损 | ✅ | `level=zp` |
| **咪咕音乐** | ✅ | — | ✅ | 中国移动曲库 |
| **Bilibili** | ✅ | 可变 | ✅ | 启发式过滤非音乐内容 |
| **歌词千寻** | ✅ | — | ✅ | MusicFree JS 桥接 |

---

## 🚀 开发

### 环境要求

- Flutter 3.41+
- Windows 10+ / macOS 12+ / Linux
- 构建工具 (Visual Studio / Xcode / GTK)

### 快速启动

```powershell
cd tonic-stream
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

### 构建

```powershell
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

---

## 🏗️ 架构

```
lib/
  core/source/          # 音源抽象层 (TonicAudioSource)
    models.dart         # TonicSourceMatch, TonicSourceStream, QualityTag
    source_aggregator.dart  # 并发搜索 + 延迟追踪 + 动态优先级
    source_router.dart  # 音源路由 (内置 → 插件)
  services/sources/     # 音源实现
    netease/            # 网易云音乐
    qqmusic/            # QQ音乐
    kuwo/               # 酷我音乐
    migu/               # 咪咕音乐
    bilibili/           # Bilibili
    musicfree/          # MusicFree JS 桥接层
```

### 设计理念

- **音源抽象** — `TonicAudioSource` 接口统一搜索 (`search`) 和流获取 (`getStreams`)
- **并发优先** — 多音源同时搜索，`searchStreamed()` 流式发射结果
- **动态排序** — 追踪每个音源的响应延迟，自动优先快速源
- **品质标识** — `QualityTag` (lossless/high/standard/unknown) 帮助用户选择
- **插件扩展** — MusicFree JS 插件桥接层，复用已有生态

---

## 🧪 测试

```powershell
# 运行所有 test/core/source 测试
flutter test test/core/source/

# 运行全部测试（排除已知 drift schema 问题）
flutter test --exclude-tags drift
```

---

## 💼 许可证

Tonic 基于 [BSD-4-Clause](LICENSE) 协议开源。

本项目基于 [Spotube](https://github.com/KRTirtho/spotube) (BSD-4-Clause) 构建。

MusicFree 插件桥接兼容 [AGPL-3.0](https://github.com/maotoumao/MusicFree) 插件格式。

---

<div align="center">
  <sub>以 ❤️ 和 🎵 构建 | © Tonic 2026</sub>
</div>
