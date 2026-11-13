
import SwiftUI
import AVKit

struct LocalVideoPlayerView: View {
    let url: URL
    let title: String

    @State private var player: AVPlayer?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("视频无法播放")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if isLoading {
                ProgressView("正在加载视频")
                    .tint(MusicTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MusicTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadVideo() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "找不到视频文件，请重新导入。"
            isLoading = false
            return
        }

        let instance = AVPlayer(url: url)

        instance.currentItem?.asset.loadValuesAsynchronously(
            forKeys: ["playable"]
        ) {
            DispatchQueue.main.async {
                let status = instance.currentItem?.asset.statusOfValue(
                    forKey: "playable",
                    error: nil
                )

                if status == .loaded {
                    player = instance
                    isLoading = false
                } else {
                    errorMessage = "视频格式不受支持或文件已损坏。"
                    isLoading = false
                }
            }
        }
    }
}
