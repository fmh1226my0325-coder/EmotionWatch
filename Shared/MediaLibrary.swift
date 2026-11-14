
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

                return MediaItem(
                    title: url.deletingPathExtension().lastPathComponent,
                    kind: kind,
                    fileName: url.lastPathComponent,
                    artworkFileName: kind == .audio
                        ? ArtworkManager.shared.artworkFileName(
                            for: url.lastPathComponent
                        )
                        : nil
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

    // 保留同步接口，兼容现有 MusicHomeView 调用方式。
    func importFiles(_ urls: [URL]) {
        Task {
            await performImport(urls)
        }
    }

    private func performImport(_ urls: [URL]) async {
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

            do {
                let destination = try copyFile(from: source)
                successCount += 1

                // 仅对音频文件提取内嵌封面。
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

        // 封面提取结束后刷新，重新关联封面文件名。
        refresh()

        if failures.isEmpty {
            importMessage = "成功导入 \(successCount) 个文件"
            errorMessage = nil
        } else {
            importMessage =
                "成功导入 \(successCount) 个文件；失败 \(failures.count) 个"
            errorMessage = failures.joined(separator: "\n")
        }
    }

    // 单独管理安全作用域，复制完成后立即释放。
    private func copyFile(from source: URL) throws -> URL {
        let accessed = source.startAccessingSecurityScopedResource()

        defer {
            if accessed {
                source.stopAccessingSecurityScopedResource()
            }
        }

        let destination = uniqueDestination(
            for: source.lastPathComponent
        )

        try FileManager.default.copyItem(
            at: source,
            to: destination
        )

        return destination
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

    // MARK: - 存储空间

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

        guard FileManager.default.fileExists(atPath: base.path) else {
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
