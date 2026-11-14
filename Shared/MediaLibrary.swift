
import Foundation
import SwiftUI

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var importMessage: String?

    private let supportedAudio: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff", "caf"
    ]

    private let supportedVideo: Set<String> = [
        "mp4", "mov", "m4v"
    ]

    var audioItems: [MediaItem] {
        items.filter { $0.kind == .audio }
    }

    var videoItems: [MediaItem] {
        items.filter { $0.kind == .video }
    }

    private var documentsURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    func fileURL(for item: MediaItem) -> URL {
        documentsURL.appendingPathComponent(item.fileName)
    }

    // MARK: - 刷新媒体库

    func refresh() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            items = urls.compactMap { url in
                let ext = url.pathExtension.lowercased()

                let kind: MediaKind

                if supportedAudio.contains(ext) {
                    kind = .audio
                } else if supportedVideo.contains(ext) {
                    kind = .video
                } else {
                    return nil
                }

                let artworkFileName: String?

                if kind == .audio {
                    artworkFileName =
                        ArtworkManager.shared.artworkFileName(
                            for: url.lastPathComponent
                        )
                } else {
                    artworkFileName = nil
                }

                return MediaItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    kind: kind,
                    fileName: url.lastPathComponent,
                    artworkFileName: artworkFileName
                )
            }.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title)
                    == .orderedAscending
            }

            errorMessage = nil
        } catch {
            errorMessage = "读取媒体库失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 导入文件

    func importFiles(_ urls: [URL]) async {
        let fileManager = FileManager.default
        var successCount = 0
        var failures: [String] = []

        for source in urls {
            let ext = source.pathExtension.lowercased()

            guard supportedAudio.contains(ext)
                    || supportedVideo.contains(ext)
                    || ext == "lrc" else {
                failures.append(
                    "\(source.lastPathComponent)：不支持的格式"
                )
                continue
            }

            let accessed = source.startAccessingSecurityScopedResource()

            defer {
                if accessed {
                    source.stopAccessingSecurityScopedResource()
                }
            }

            let destination = uniqueDestination(
                for: source.lastPathComponent
            )

            do {
                try fileManager.copyItem(
                    at: source,
                    to: destination
                )

                successCount += 1

                // 音频导入成功后，提取并保存内嵌封面
                if supportedAudio.contains(ext) {
                    _ = await ArtworkManager.shared.extractAndSaveArtwork(
                        from: destination,
                        audioFileName: destination.lastPathComponent
                    )
                }
            } catch {
                failures.append(
                    "\(source.lastPathComponent)：\(error.localizedDescription)"
                )
            }
        }

        refresh()

        importMessage = "成功导入 \(successCount) 个文件"

        if failures.isEmpty {
            errorMessage = nil
        } else {
            errorMessage = failures.joined(separator: "\n")
        }
    }

    // MARK: - 删除文件

    func delete(_ item: MediaItem) {
        do {
            try FileManager.default.removeItem(
                at: fileURL(for: item)
            )

            if item.kind == .audio {
                ArtworkManager.shared.removeArtwork(
                    for: item.fileName
                )
            }

            refresh()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    // MARK: - 文件大小

    var totalBytes: Int64 {
        items.reduce(0) { total, item in
            let values = try? fileURL(for: item)
                .resourceValues(forKeys: [.fileSizeKey])

            return total + Int64(values?.fileSize ?? 0)
        }
    }

    // MARK: - 避免文件重名

    private func uniqueDestination(for name: String) -> URL {
        let base = documentsURL.appendingPathComponent(name)

        if !FileManager.default.fileExists(atPath: base.path) {
            return base
        }

        let stem = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        var index = 2

        while true {
            let suffix = ext.isEmpty ? "" : ".\(ext)"

            let candidate = documentsURL.appendingPathComponent(
                "\(stem)-\(index)\(suffix)"
            )

            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }

            index += 1
        }
    }
}
