import Foundation
import AVFoundation

public enum OfflineMediaType: String, Codable {
    case audio
    case video
}

public struct OfflineMediaItem: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let type: OfflineMediaType
    public let url: URL

    public init(id: UUID = UUID(), title: String, type: OfflineMediaType, url: URL) {
        self.id = id
        self.title = title
        self.type = type
        self.url = url
    }
}

public final class OfflineMediaLibrary: ObservableObject {
    @Published public var items: [OfflineMediaItem] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public init() {
        loadLocalLibrary()
    }

    public func loadLocalLibrary() {
        isLoading = true
        errorMessage = nil

        var discovered: [OfflineMediaItem] = []

        let supportedExtensions: Set<String> = ["mp3", "m4a", "mp4", "mov"]

        let fm = FileManager.default
        let documentsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let bundleURL = Bundle.main.resourceURL

        let baseURLs = [documentsURL, bundleURL].compactMap { $0 }

        for baseURL in baseURLs {
            if let enumerator = fm.enumerator(at: baseURL, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    guard supportedExtensions.contains(ext) else { continue }

                    let type: OfflineMediaType = (ext == "mp3" || ext == "m4a") ? .audio : .video
                    let title = fileURL.deletingPathExtension().lastPathComponent
                    discovered.append(OfflineMediaItem(title: title, type: type, url: fileURL))
                }
            }
        }

        let unique = Dictionary(uniqueKeysWithValues: discovered.map { ($0.url.path, $0) }).values.sorted {
            $0.title.lowercased() < $1.title.lowercased()
        }

        items = unique
        isLoading = false

        if items.isEmpty {
            errorMessage = "暂未发现本地媒体文件，需先把 MP3/MP4 同步到 App 的 Documents 目录。"
        }
    }
}
