
import SwiftUI

struct MusicHomeView: View {
    @StateObject private var library = MediaLibrary()
    @StateObject private var player = OfflinePlayer()

    @State private var showingImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    section("最近添加", subtitle: "继续聆听") {
                        if library.audioItems.isEmpty {
                            empty("还没有本地音乐")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(library.audioItems.prefix(10)) { item in
                                        Button {
                                            player.setQueue(
                                                library.audioItems,
                                                startAt: item
                                            )
                                        } label: {
                                            VStack(alignment: .leading, spacing: 7) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [
                                                                    MusicTheme.softRed,
                                                                    MusicTheme.accent
                                                                ],
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )

                                                    Image(systemName: "music.note")
                                                        .font(.largeTitle)
                                                        .foregroundStyle(.white)
                                                }
                                                .frame(width: 112, height: 112)

                                                Text(item.title)
                                                    .font(.caption.weight(.semibold))
                                                    .lineLimit(1)
                                                    .frame(width: 112, alignment: .leading)

                                                Text(item.artist)
                                                    .font(.caption2)
                                                    .foregroundStyle(MusicTheme.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }

                    section("我的音乐", subtitle: "本地媒体库") {
                        NavigationLink {
                            MediaListView(
                                title: "本地音乐",
                                items: library.audioItems,
                                library: library,
                                player: player
                            )
                        } label: {
                            menuCard(
                                "music.note.list",
                                "本地歌曲",
                                "\(library.audioItems.count) 首歌曲",
                                MusicTheme.accent
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            PlaybackView(player: player)
                        } label: {
                            menuCard(
                                "waveform",
                                "正在播放",
                                player.currentItem?.title ?? "暂未播放",
                                MusicTheme.softRed
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    section("视频中心", subtitle: "本地视频") {
                        NavigationLink {
                            MediaListView(
                                title: "本地视频",
                                items: library.videoItems,
                                library: library,
                                player: player
                            )
                        } label: {
                            menuCard(
                                "play.rectangle.fill",
                                "我的视频",
                                "\(library.videoItems.count) 个视频",
                                .orange
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    section("媒体库", subtitle: "文件状态") {
                        HStack {
                            statCard(
                                "music.note",
                                "\(library.audioItems.count)",
                                "音乐"
                            )

                            statCard(
                                "video",
                                "\(library.videoItems.count)",
                                "视频"
                            )

                            statCard(
                                "internaldrive",
                                ByteCountFormatter.string(
                                    fromByteCount: library.totalBytes,
                                    countStyle: .file
                                ),
                                "占用"
                            )
                        }
                    }

                    if let message = library.importMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(MusicTheme.accent)
                    }

                    if let error = library.errorMessage ?? importError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let error = player.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(14)
            }
            .background(MusicTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(MusicTheme.accent)
                    }
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImporter) {
                DocumentPicker(
                    onPick: { urls in
                        showingImporter = false

                        Task {
                            await library.importFiles(urls)
                        }

                        importError = nil
                    },
                    onCancel: {
                        showingImporter = false
                    }
                )
                .ignoresSafeArea()
            }
            .onAppear {
                library.refresh()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Music")
                    .font(.system(size: 28, weight: .bold))

                Text("让音乐陪伴你的每一刻")
                    .font(.caption)
                    .foregroundStyle(MusicTheme.secondary)
            }

            Spacer()

            Button {
                showingImporter = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(MusicTheme.card, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private func section<Content: View>(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(MusicTheme.secondary)
            }

            content()
        }
        .foregroundStyle(.white)
    }

    private func menuCard(
        _ icon: String,
        _ title: String,
        _ subtitle: String,
        _ color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(
                    color.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: 12)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(MusicTheme.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(MusicTheme.secondary)
        }
        .padding(12)
        .background(
            MusicTheme.panel,
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func statCard(
        _ icon: String,
        _ count: String,
        _ title: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(MusicTheme.accent)

            Text(count)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(title)
                .font(.caption2)
                .foregroundStyle(MusicTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            MusicTheme.panel,
            in: RoundedRectangle(cornerRadius: 14)
        )
    }

    private func empty(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(MusicTheme.secondary)
            .frame(maxWidth: .infinity)
            .padding(22)
            .background(
                MusicTheme.panel,
                in: RoundedRectangle(cornerRadius: 14)
            )
    }
}

struct MediaListView: View {
    let title: String
    let items: [MediaItem]

    @ObservedObject var library: MediaLibrary
    @ObservedObject var player: OfflinePlayer

    var body: some View {
        List(items) { item in
            NavigationLink {
                if item.kind == .audio {
                    PlaybackView(player: player)
                        .onAppear {
                            player.setQueue(
                                library.audioItems,
                                startAt: item
                            )
                        }
                } else {
                    LocalVideoPlayerView(
                        url: library.fileURL(for: item),
                        title: item.title
                    )
                }
            } label: {
                HStack(spacing: 12) {
                    Image(
                        systemName: item.kind == .audio
                            ? "music.note"
                            : "play.rectangle.fill"
                    )
                    .foregroundStyle(MusicTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        MusicTheme.card,
                        in: RoundedRectangle(cornerRadius: 10)
                    )

                    VStack(alignment: .leading) {
                        Text(item.title)
                            .lineLimit(1)

                        Text(
                            item.kind == .audio
                                ? "本地音频"
                                : "本地视频"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(MusicTheme.panel)
        }
        .scrollContentBackground(.hidden)
        .background(MusicTheme.background)
        .navigationTitle(title)
    }
}

struct PlaybackView: View {
    @ObservedObject var player: OfflinePlayer
    @State private var lyrics: [LyricLine] = []

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            MusicTheme.softRed,
                            MusicTheme.accent
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 75))
                        .foregroundStyle(.white)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 30)

            Text(player.currentItem?.title ?? "暂无播放内容")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(player.currentItem?.artist ?? "选择本地歌曲开始播放")
                .font(.subheadline)
                .foregroundStyle(MusicTheme.secondary)

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 1)
            )
            .tint(MusicTheme.accent)
            .padding(.horizontal)

            HStack {
                Text(clock(player.currentTime))
                Spacer()
                Text(clock(player.duration))
            }
            .font(.caption.monospaced())
            .foregroundStyle(MusicTheme.secondary)
            .padding(.horizontal)

            HStack(spacing: 42) {
                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }

                Button {
                    player.togglePlayPause()
                } label: {
                    Image(
                        systemName: player.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 66, height: 66)
                    .background(MusicTheme.accent, in: Circle())
                }

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            HStack {
                Button(player.repeatMode.rawValue) {
                    player.cycleRepeatMode()
                }
                .foregroundStyle(MusicTheme.accent)

                Spacer()
            }
            .font(.caption)
            .padding(.horizontal)

            if let error = player.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if !lyrics.isEmpty {
                let index = LyricsManager.index(
                    at: player.currentTime,
                    in: lyrics
                )

                Text(lyrics[index].text)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if player.currentItem != nil {
                Text("暂无匹配歌词")
                    .font(.caption)
                    .foregroundStyle(MusicTheme.secondary)
            }

            Spacer()
        }
        .padding()
        .background(MusicTheme.background.ignoresSafeArea())
        .navigationTitle("正在播放")
        .onAppear {
            loadLyrics()
        }
        .onChange(of: player.currentItem) { _, _ in
            loadLyrics()
        }
    }

    private func loadLyrics() {
        guard let item = player.currentItem else {
            lyrics = []
            return
        }

        lyrics = LyricsManager.load(for: item.fileName)
    }

    private func clock(_ value: Double) -> String {
        guard value.isFinite else {
            return "00:00"
        }

        let seconds = max(0, Int(value))

        return String(
            format: "%02d:%02d",
            seconds / 60,
            seconds % 60
        )
    }
}
