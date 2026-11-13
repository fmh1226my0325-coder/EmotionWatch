# EmotionWatch Offline Watch Media

这是一个适合 Apple Watch 的离线媒体播放器雏形，支持：

- 本地音频播放：MP3、M4A
- 本地视频播放：MP4、MOV
- 离线播放：从 Watch 本地文件或 App Bundle 中读取媒体
- 简单的播放列表和控制界面

这个仓库目前是一个可扩展的 watchOS 代码骨架，方便你在 Xcode 中继续开发成完整产品。

## 目录结构

- `Sources/EmotionWatchWatchApp/EmotionWatchWatchApp.swift`：App 入口
- `Sources/EmotionWatchWatchApp/MediaLibrary.swift`：本地媒体扫描和数据模型
- `Sources/EmotionWatchWatchApp/OfflineMediaPlayer.swift`：播放控制
- `Sources/EmotionWatchWatchApp/ContentView.swift`：UI 页面

## 适合的开发方式

1. 在 Xcode 中创建一个 watchOS App
2. 让 `Sources/EmotionWatchWatchApp` 下的 Swift 文件加入目标
3. 在 Watch App 中使用 `Documents` 目录同步离线文件
4. 将 MP3、MP4 等媒体文件复制到 App 的 `Documents` 路径

## 典型本地文件目录

例如：

```
/var/mobile/Containers/Data/Application/.../Documents/
```

你可以在 WatchKit 扩展或 iPhone App 中将文件同步到这里，再让 watchOS 读取。

## 关键设计点

- `OfflineMediaLibrary` 会扫描本地文件，并自动识别 `.mp3`, `.m4a`, `.mp4`, `.mov`
- `OfflineMediaPlayer` 使用 `AVPlayer` 统一处理音频和视频
- `ContentView` 提供播放列表和单个媒体播放界面

## 下一步建议

- 增加“下载管理”功能，允许从 iPhone 侧同步到 Watch
- 支持字幕、播放列表保存、进度记忆
- 增加更适合 watchOS 的交互设计，例如数字表盘快捷播放

## 说明

这份代码是一个起步版本，适合在真实项目中继续扩展。你也可以将它直接做成一个更完整的 watchOS 问题/治疗类健康 App 的离线播放模块。
