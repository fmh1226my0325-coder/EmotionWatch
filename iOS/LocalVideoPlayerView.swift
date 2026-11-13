import SwiftUI
import AVKit

struct LocalVideoPlayerView: View {
    let url: URL
    let title: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView("正在加载视频").tint(MusicTheme.accent)
            }
        }
        .background(MusicTheme.background.ignoresSafeArea())
        .navigationTitle(title)
        .onAppear {
            let instance = AVPlayer(url: url)
            player = instance
            instance.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
