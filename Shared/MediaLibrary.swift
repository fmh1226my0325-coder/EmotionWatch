
import Foundation
import SwiftUI
import Combine

@MainActor
final class MediaLibrary: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published var errorMessage: String?
    @Published var importMessage: String?

    private let supportedAudio: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aiff", "caf", "flac"
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
                    fileName: url.lastPathComponent
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

    func importFiles(_ urls: [URL]) {
        let fileManager = FileManager.default
        var successCount = 0
        var errors: [String] = []

        for source in urls {
            let accessed = source.startAccessingSecurityScopedResource()

            defer {
                if accessed {
                    source.stopAccessingSecurityScopedResource()
                }
            }

            let ext = source.pathExtension.lowercased()

            guard supportedAudio.contains(ext)
                    || supportedVideo.contains(ext)
                    || ext == "lrc" else {
                errors.append("不支持的文件：\(source.lastPathComponent)")
                continue
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
            } catch {
                errors.append(
                    "\(source.lastPathComponent)：\(error.localizedDescription)"
                )
            }
        }

        refresh()

        if errors.isEmpty {
            importMessage = "成功导入 \(successCount) 个文件"
            errorMessage = nil
        } else {
            importMessage = "成功导入 \(successCount) 个文件"
            errorMessage = errors.joined(separator: "\n")
        }
    }

    func delete(_ item: MediaItem) {
        do {
            try FileManager.default.removeItem(
                at: fileURL(for: item)
            )
            refresh()
        } catch {
            errorMessage = "删除失败：\(error.localizedDescription)"
        }
    }

    var totalBytes: Int64 {
        items.reduce(0) { total, item in
            let values = try? fileURL(for: item)
                .resourceValues(forKeys: [.fileSizeKey])

            return total + Int64(values?.fileSize ?? 0)
        }
    }

    private func uniqueDestination(for name: String) -> URL {
        let base = documentsURL.appendingPathComponent(name)

        if !FileManager.default.fileExists(atPath: base.path) {
            return base
        }

        let stem = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        var index = 2

        while true {
            let candidate = documentsURL.appendingPathComponent(
                "\(stem)-\(index).\(ext)"
            )

            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }

            index += 1
        }
    }
}
