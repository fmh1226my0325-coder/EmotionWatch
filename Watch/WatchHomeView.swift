import SwiftUI
import AVFoundation

struct WatchHomeView: View {
    @StateObject private var library = MediaLibrary()
    @StateObject private var player = OfflinePlayer()
    @StateObject private var transfer = WatchTransferManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section("离线音乐") {
                    if library.audioItems.isEmpty {
                        Text("暂无歌曲\n请先从 iPhone 传输音乐").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(library.audioItems) { item in
                        Button {
                            player.setQueue(library.audioItems, startAt: item)
                        } label: {
                            HStack {
                                Image(systemName: "music.note").foregroundStyle(MusicTheme.accent)
                                VStack(alignment: .leading) {
                                    Text(item.title).lineLimit(1)
                                    Text(item.artist).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if player.currentItem?.id == item.id && player.isPlaying {
                                    Image(systemName: "waveform")
                                }
                            }
                        }
                    }
                }
                Section("播放控制") {
                    if let item = player.currentItem {
                        Text(item.title).font(.headline).lineLimit(2)
                        HStack {
                            Button { player.previous() } label: { Image(systemName: "backward.fill") }
                            Button { player.togglePlayPause() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill") }
                            Button { player.next() } label: { Image(systemName: "forward.fill") }
                        }.buttonStyle(.bordered)
                        if player.duration > 0 {
                            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 1))
                        }
                    } else {
                        Text("选择歌曲开始播放").font(.caption)
                    }
                    Text(transfer.status).font(.caption2).foregroundStyle(.secondary)
                }
                Section("本地视频") {
                    if library.videoItems.isEmpty {
                        Text("暂无视频").font(.caption)
                    } else {
                        ForEach(library.videoItems) { item in
                            NavigationLink(item.title) {
                                WatchVideoView(title: item.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Music")
            .onAppear { library.refresh() }
        }
        .tint(MusicTheme.accent)
    }
}

struct WatchVideoView: View {
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "video.slash").font(.title2).foregroundStyle(MusicTheme.accent)
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text("当前版本暂不启用手表视频播放。手表优先保证独立音频播放。")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
}
