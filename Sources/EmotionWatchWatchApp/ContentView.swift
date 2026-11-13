import SwiftUI
import AVFoundation

final class OfflineMediaPlayer: ObservableObject {
    @Published var currentItem: OfflineMediaItem?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0

    private let player = AVPlayer()
    private var timeObserver: Any?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            let seconds = CMTimeGetSeconds(time)
            self.currentTime = seconds
            if let item = self.player.currentItem {
                let total = CMTimeGetSeconds(item.duration)
                if total.isFinite && total > 0 {
                    self.duration = total
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    @objc private func playerDidFinish() {
        isPlaying = false
        currentTime = 0
    }

    func load(_ item: OfflineMediaItem) {
        currentItem = item
        let playerItem = AVPlayerItem(url: item.url)
        player.replaceCurrentItem(with: playerItem)
        currentTime = 0
        duration = 0
        play()
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time)
        currentTime = seconds
    }
}

struct ContentView: View {
    @EnvironmentObject private var library: OfflineMediaLibrary
    @StateObject private var player = OfflineMediaPlayer()
    @State private var selectedItem: OfflineMediaItem?

    var body: some View {
        NavigationStack {
            VStack {
                if library.items.isEmpty {
                    VStack(spacing: 12) {
                        Text("没有发现离线媒体")
                            .font(.headline)
                        Text(library.errorMessage ?? "请先同步本地音视频文件到 Documents")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(library.items) { item in
                        Button {
                            selectedItem = item
                            player.load(item)
                        } label: {
                            HStack {
                                Image(systemName: item.type == .audio ? "music.note" : "play.rectangle.fill")
                                VStack(alignment: .leading) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.type == .audio ? "音频" : "视频")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedItem?.id == item.id && player.isPlaying {
                                    Image(systemName: "waveform")
                                }
                            }
                        }
                    }
                }

                if let item = selectedItem {
                    VStack(spacing: 12) {
                        if item.type == .video {
                            VideoPlayerView(player: player.player)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            HStack {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                Text(player.isPlaying ? "正在播放：" : "已准备：")
                                Text(item.title)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }

                        HStack {
                            Button(action: { player.togglePlayPause() }) {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                Text(player.isPlaying ? "暂停" : "播放")
                            }
                            .buttonStyle(.borderedProminent)

                            if player.duration > 0 {
                                Slider(value: Binding(
                                    get: { player.currentTime },
                                    set: { player.seek(to: $0) }
                                ), in: 0...player.duration)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .navigationTitle("离线播放器")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        library.loadLocalLibrary()
                    }
                }
            }
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let container = UIView(frame: .zero)
        container.backgroundColor = .black

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = container.bounds
        container.layer.addSublayer(layer)

        DispatchQueue.main.async {
            layer.frame = container.bounds
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            layer.player = player
            layer.frame = uiView.bounds
        }
    }
}

private extension OfflineMediaPlayer {
    var player: AVPlayer {
        AVPlayer() // placeholder to keep access legal in the view, replaced by property in class scope
    }
}
