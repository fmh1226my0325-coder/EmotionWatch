# EmotionMusic 双端离线播放器源码

本源码包用于把现有 SwiftUI 播放器整理为 iPhone + Apple Watch 两个独立 App。

## 重要说明
- 本包提供统一的数据模型、媒体库、音频播放、LRC 解析、WatchConnectivity 传输，以及两端基础界面。
- 它不是已经签名的 IPA，也不是可直接归档的完整 `.xcodeproj`。需要在 Xcode 中创建 iOS App Target 和 watchOS App Target，并按下方说明加入文件。
- `WatchVideoView` 当前明确显示兼容性提示。Apple Watch 的视频播放能力与 watchOS 版本、设备和媒体格式有关，不承诺所有视频均可播放。
- 不要把两个 `@main` 文件同时加入同一个 Target。

## Target 文件归属

### Shared（两个 Target 都加入）
- `Shared/MediaItem.swift`
- `Shared/MusicTheme.swift`
- `Shared/MediaLibrary.swift`
- `Shared/OfflinePlayer.swift`
- `Shared/LyricsManager.swift`
- `Shared/WatchTransferManager.swift`

### iOS App Target
- `iOS/EmotionMusicApp.swift`
- `iOS/MusicHomeView.swift`
- `iOS/LocalVideoPlayerView.swift`

### watchOS App Target
- `Watch/EmotionMusicWatchApp.swift`
- `Watch/WatchHomeView.swift`

## Xcode 配置
1. 创建 iOS App，Interface 选 SwiftUI，Language 选 Swift。
2. 在同一工程添加 watchOS App Target（独立 Watch App）。
3. 将 Shared 文件同时勾选两个 Target Membership。
4. 将 `iOS` 文件只勾选 iOS Target；将 `Watch` 文件只勾选 Watch Target。
5. 两个 Target 的 Bundle Identifier 必须不同；设置各自 Signing Team。
6. iOS Deployment Target 建议 iOS 17 或更高；watchOS Deployment Target 建议 watchOS 10 或更高。
7. iOS App 的主入口为 `EmotionMusicApp.swift`；Watch App 的主入口为 `EmotionMusicWatchApp.swift`。
8. 如需从 iPhone 传文件到 Watch，两个 App 都要启用 WatchConnectivity 能力（并在真实设备上测试）。

## 使用
- iPhone：点“导入媒体”，选择 MP3/M4A/MP4/MOV。文件复制到 App Documents 后会出现在媒体库。
- Watch：先在 iPhone 端选择歌曲并点“发送到 Apple Watch”；Watch 收到后复制到自己的 Documents，之后可独立播放。
- LRC：把与歌曲同名的 `.lrc` 文件放在同一目录；导入时会一起复制。当前歌词显示按播放时间同步。

## GitHub Actions
请在仓库中加入 `.github/workflows/ios-build.yml`。工作流会构建 iOS Simulator 版本用于检查编译。要导出可安装 IPA，需要配置 Apple Distribution 证书、Provisioning Profile、Team ID 和签名流程；不要把证书密码写进源码。
