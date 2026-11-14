
import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI

#if os(iOS)
import UIKit
#endif

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
    @Published var errorMessage: String?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var remoteTargets: [(MPRemoteCommand, Any)] = []

    #if os(iOS)
    private var cachedArtworkFileName: String?
    private var cachedArtwork: MPMediaItemArtwork?
    #endif

    init() {
        configureAudioSession()
        configureRemoteCommands()
        configureObservers()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        for (command, target) in remoteTargets {
            command.removeTarget(target)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try session.setActive(true)
        } catch {
            errorMessage = "音频会话配置失败：\(error.localizedDescription)"
        }
    }

    private func configureObservers() {
        timeObserver = player.addPeriodicTimeObserver(
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
                self.updateNowPlayingInfo()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handlePlaybackEnd()
            }
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        addRemoteTarget(center.playCommand) { [weak self] in
            self?.resume()
            return .success
        }

        addRemoteTarget(center.pauseCommand) { [weak self] in
            self?.pause()
            return .success
        }

        addRemoteTarget(center.nextTrackCommand) { [weak self] in
            self?.next()
            return .success
        }

        addRemoteTarget(center.previousTrackCommand) { [weak self] in
            self?.previous()
            return .success
        }

        addRemoteTarget(center.changePlaybackPositionCommand) { [weak self] event in
            guard
                let self,
                let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            self.seek(to: positionEvent.positionTime)
            return .success
        }

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
    }

    private func addRemoteTarget(
        _ command: MPRemoteCommand,
        handler: @escaping () -> MPRemoteCommandHandlerStatus
    ) {
        let target = command.addTarget { _ in
            handler()
        }

        remoteTargets.append((command, target))
    }

    private func addRemoteTarget(
        _ command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let target = command.addTarget(handler: handler)
        remoteTargets.append((command, target))
    }

    func setQueue(_ items: [MediaItem], startAt item: MediaItem) {
        queue = items.filter { $0.kind == .audio }
        play(item: item)
    }

    func play(item: MediaItem) {
        guard item.kind == .audio else { return }

        let url = documentsURL.appendingPathComponent(item.fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "找不到音频文件：\(item.fileName)"
            return
        }

        currentItem = item
        errorMessage = nil
        currentTime = 0
        duration = 0

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)

        statusObserver = playerItem.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] observedItem, _ in
            Task { @MainActor in
                guard let self else { return }

                if observedItem.status == .failed {
                    self.errorMessage = observedItem.error?.localizedDescription
                        ?? "音频加载失败"
                    self.pause()
                }
            }
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "无法启动音频：\(error.localizedDescription)"
            return
        }

        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard player.currentItem != nil else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
            errorMessage = nil
            updateNowPlayingInfo()
        } catch {
            errorMessage = "恢复播放失败：\(error.localizedDescription)"
        }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }

        let upperBound = duration > 0 ? duration : seconds
        let bounded = max(0, min(seconds, upperBound))

        player.seek(
            to: CMTime(seconds: bounded, preferredTimescale: 600)
        )

        currentTime = bounded
        updateNowPlayingInfo()
    }

    func next() {
        guard !queue.isEmpty else { return }

        let nextItem: MediaItem?

        if repeatMode == .shuffle {
            let choices = queue.filter { $0.id != currentItem?.id }
            nextItem = choices.randomElement() ?? queue.first
        } else if let currentItem,
                  let index = queue.firstIndex(of: currentItem) {
            let nextIndex = index + 1

            if nextIndex < queue.count {
                nextItem = queue[nextIndex]
            } else {
                nextItem = repeatMode == .all ? queue.first : nil
            }
        } else {
            nextItem = queue.first
        }

        if let nextItem {
            play(item: nextItem)
        } else {
            pause()
        }
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }

        guard !queue.isEmpty else { return }

        if let currentItem,
           let index = queue.firstIndex(of: currentItem) {
            let previousIndex = index - 1

            let target: MediaItem?

            if previousIndex >= 0 {
                target = queue[previousIndex]
            } else {
                target = repeatMode == .all ? queue.last : nil
            }

            if let target {
                play(item: target)
            }
        }
    }

    func cycleRepeatMode() {
        let modes = RepeatMode.allCases
        let index = modes.firstIndex(of: repeatMode) ?? 0
        repeatMode = modes[(index + 1) % modes.count]
    }

    private func handlePlaybackEnd() {
        if repeatMode == .one, let currentItem {
            play(item: currentItem)
        } else {
            next()
        }
    }

    // MARK: - 锁屏播放信息

    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        #if os(iOS)
        if let artwork = loadLockScreenArtwork(for: item) {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        #endif

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    #if os(iOS)
    // MARK: - 读取锁屏封面

    private func loadLockScreenArtwork(
        for item: MediaItem
    ) -> MPMediaItemArtwork? {
        guard let fileName = item.artworkFileName,
              !fileName.isEmpty else {
            cachedArtworkFileName = nil
            cachedArtwork = nil
            return nil
        }

        if cachedArtworkFileName == fileName {
            return cachedArtwork
        }

        let artworkURL = documentsURL
            .appendingPathComponent("Artwork", isDirectory: true)
            .appendingPathComponent(fileName)

        guard let image = UIImage(contentsOfFile: artworkURL.path) else {
            cachedArtworkFileName = fileName
            cachedArtwork = nil
            return nil
        }

        let artwork = MPMediaItemArtwork(
            boundsSize: image.size
        ) { _ in
            image
        }

        cachedArtworkFileName = fileName
        cachedArtwork = artwork

        return artwork
    }
    #endif

    private var documentsURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }
}
