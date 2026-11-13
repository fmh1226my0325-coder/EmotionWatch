import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class OfflinePlayer: ObservableObject {
    enum RepeatMode: String, CaseIterable {
        case all = "列表循环"
        case one = "单曲循环"
        case shuffle = "随机播放"
    }

    let player = AVPlayer()
    @Published private(set) var queue: [MediaItem] = []
    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var repeatMode: RepeatMode = .all

    private var observer: Any?
    private var endObserver: NSObjectProtocol?

    init() {
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                self.currentTime = seconds.isFinite ? max(0, seconds) : 0
                let total = self.player.currentItem?.duration.seconds ?? 0
                self.duration = total.isFinite ? max(0, total) : 0
                self.isPlaying = self.player.rate != 0
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handlePlaybackEnd() }
        }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func setQueue(_ items: [MediaItem], startAt item: MediaItem) {
        queue = items.filter { $0.kind == .audio }
        play(item: item)
    }

    func play(item: MediaItem) {
        guard item.kind == .audio else { return }
        currentItem = item
        let url = documentsURL.appendingPathComponent(item.fileName)
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        currentTime = 0
        duration = 0
        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func resume() {
        guard player.currentItem != nil else { return }
        player.play()
        isPlaying = true
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let bounded = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: bounded, preferredTimescale: 600))
        currentTime = bounded
    }

    func next() {
        guard !queue.isEmpty else { return }
        let nextItem: MediaItem?
        if repeatMode == .shuffle {
            let choices = queue.filter { $0.id != currentItem?.id }
            nextItem = choices.randomElement() ?? queue.first
        } else if let currentItem, let index = queue.firstIndex(of: currentItem) {
            let nextIndex = index + 1
            nextItem = nextIndex < queue.count ? queue[nextIndex] : (repeatMode == .all ? queue.first : nil)
        } else {
            nextItem = queue.first
        }
        if let nextItem { play(item: nextItem) } else { pause() }
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        if let currentItem, let index = queue.firstIndex(of: currentItem) {
            let previousIndex = index - 1
            let target = previousIndex >= 0 ? queue[previousIndex] : (repeatMode == .all ? queue.last : nil)
            if let target { play(item: target) }
        }
    }

    func cycleRepeatMode() {
        let all = RepeatMode.allCases
        let index = all.firstIndex(of: repeatMode) ?? 0
        repeatMode = all[(index + 1) % all.count]
    }

    private func handlePlaybackEnd() {
        if repeatMode == .one, let currentItem {
            play(item: currentItem)
        } else {
            next()
        }
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
