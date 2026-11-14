
import Foundation

enum MediaKind: String, Codable, CaseIterable {
    case audio
    case video
}

struct MediaItem: Identifiable, Hashable, Codable {
    var id: UUID
    var title: String
    var artist: String
    var kind: MediaKind
    var fileName: String
    var duration: Double

    // 对应 Documents/Artwork 文件夹中的封面文件
    var artworkFileName: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "本地文件",
        kind: MediaKind,
        fileName: String,
        duration: Double = 0,
        artworkFileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.kind = kind
        self.fileName = fileName
        self.duration = duration
        self.artworkFileName = artworkFileName
    }
}
