import Foundation
import AVFoundation
import ImageIO
import CryptoKit

/// 跨平台（iOS 17 / watchOS 10）封面提取与本地文件管理器。
/// 只依赖 AVFoundation、Foundation、ImageIO、CryptoKit，不引用 UIKit / MediaPlayer。
final class ArtworkManager {
    static let shared = ArtworkManager()

    private let artworkDirectory: URL
    private let fileManager = FileManager.default

    /// 支持的封面文件扩展名，按优先级排列。
    private let supportedExtensions = ["jpg", "jpeg", "png", "heic", "webp"]

    private init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        artworkDirectory = documents.appendingPathComponent("Artwork", isDirectory: true)
        try? fileManager.createDirectory(at: artworkDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 对外接口

    /// 根据音频文件名查找已存在的、且**通过图片有效性校验**的封面文件名。
    /// 文件不存在或文件损坏（无法被 CGImageSource 识别、无法解码第一帧）时返回 nil。
    func artworkFileName(for audioFileName: String) -> String? {
        let hash = Self.sha256Hex(audioFileName)
        for ext in supportedExtensions {
            let candidate = "\(hash).\(ext)"
            let url = artworkDirectory.appendingPathComponent(candidate)
            if isValidImage(at: url) {
                return candidate
            }
        }
        return nil
    }

    /// 为音频文件提取内嵌封面并保存。
    /// - 已有有效封面时直接返回，不重复提取。
    /// - 已有封面但文件损坏时，允许重新提取。
    /// - 没有内嵌封面或无法安全识别/转换图片时返回 nil，不生成错误文件。
    func extractAndSaveArtwork(from audioURL: URL, audioFileName: String) async -> String? {
        if let existing = artworkFileName(for: audioFileName) {
            return existing
        }

        removeCorruptedArtworkIfNeeded(for: audioFileName)

        guard let data = await extractEmbeddedArtworkData(from: audioURL) else {
            return nil
        }

        let (finalData, fileExtension) = await prepareImageData(data)
        guard let finalData, let fileExtension else {
            return nil
        }

        let hash = Self.sha256Hex(audioFileName)
        let fileName = "\(hash).\(fileExtension)"
        let destination = artworkDirectory.appendingPathComponent(fileName)

        do {
            try finalData.write(to: destination, options: .atomic)
            return fileName
        } catch {
            print("[ArtworkManager] 保存封面失败 \(audioFileName): \(error)")
            return nil
        }
    }

    /// 删除音频文件对应的封面（如果存在）。
    func removeArtwork(for audioFileName: String) {
        let hash = Self.sha256Hex(audioFileName)
        for ext in supportedExtensions {
            let url = artworkDirectory.appendingPathComponent("\(hash).\(ext)")
            try? fileManager.removeItem(at: url)
        }
    }

    // MARK: - 图片有效性校验

    /// 完整校验图片：文件存在 → CGImageSource 创建成功 → 至少一帧 → 第一帧可解码。
    /// 只有全部通过才算有效，损坏文件会被拒绝，从而允许重新提取。
    private func isValidImage(at url: URL) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }
        guard CGImageSourceGetCount(source) > 0 else {
            return false
        }
        // 关键新增：确认第一帧确实能被解码为 CGImage
        guard CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            return false
        }
        return true
    }

    /// 清理损坏的封面文件，避免 artworkFileName(for:) 返回无效结果。
    private func removeCorruptedArtworkIfNeeded(for audioFileName: String) {
        let hash = Self.sha256Hex(audioFileName)
        for ext in supportedExtensions {
            let url = artworkDirectory.appendingPathComponent("\(hash).\(ext)")
            if fileManager.fileExists(atPath: url.path), !isValidImage(at: url) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    // MARK: - 图片格式识别与转换

    /// 识别并验证图片数据：
    /// 1. CGImageSource 创建成功
    /// 2. 帧数 > 0
    /// 3. 第一帧可解码
    /// 满足以上条件后，已知 UTI 才原样保存；未知 UTI 或第一帧解码失败则转 JPEG；转换失败返回 nil。
    private func prepareImageData(_ data: Data) async -> (Data?, String?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return (nil, nil)
        }

        guard CGImageSourceGetCount(source) > 0 else {
            return (nil, nil)
        }

        // 关键新增：先验证第一帧是否真的能解码
        let firstFrame = CGImageSourceCreateImageAtIndex(source, 0, nil)

        if firstFrame != nil {
            // 第一帧可解码，且 UTI 是已知格式，原样保存
            if let uti = CGImageSourceGetType(source) as String? {
                switch uti {
                case "public.jpeg":
                    return (data, "jpg")
                case "public.png":
                    return (data, "png")
                case "public.heic", "public.heif":
                    return (data, "heic")
                case "org.webmproject.webp":
                    return (data, "webp")
                default:
                    break // 未知 UTI，继续尝试转 JPEG
                }
            }
        }

        // 第一帧无法解码，或 UTI 未知 → 尝试转 JPEG；转换也失败则返回 nil
        if let jpegData = convertToJPEG(data: data, source: source) {
            return (jpegData, "jpg")
        }
        return (nil, nil)
    }

    /// 用 CGImageDestination 将任意可解码的图片数据转换为 JPEG。
    /// 内部再次调用 CGImageSourceCreateImageAtIndex，若第一帧无法解码则返回 nil。
    private func convertToJPEG(data: Data, source: CGImageSource) -> Data? {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.9
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }

    // MARK: - 元数据提取

    private func extractEmbeddedArtworkData(from url: URL) async -> Data? {
        let asset = AVURLAsset(url: url)

        // 1) Common metadata
        do {
            let commonMetadata = try await asset.load(.commonMetadata)
            if let data = await firstArtworkData(in: commonMetadata) {
                return data
            }
        } catch {
            // 某些格式可能没有 common metadata，继续尝试格式特定 metadata
        }

        // 2) 格式特定 metadata（M4A 的 covr atom、MP3 的 APIC 帧等）
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                if let data = await firstArtworkData(in: items) {
                    return data
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private func firstArtworkData(in items: [AVMetadataItem]) async -> Data? {
        for item in items where isArtworkItem(item) {
            // load(.dataValue) 返回 Data?，try? 会展平为 Data?，单次解包即可
            if let data = try? await item.load(.dataValue), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    private func isArtworkItem(_ item: AVMetadataItem) -> Bool {
        if item.commonKey == .commonKeyArtwork {
            return true
        }
        if let identifier = item.identifier,
           identifier == .id3MetadataAttachedPicture {
            return true
        }
        if let key = item.key as? String, key.uppercased() == "APIC" {
            return true
        }
        return false
    }

    // MARK: - SHA-256

    /// 用完整音频文件名计算稳定的 SHA-256 十六进制字符串。
    /// 不同文件名（包括 "My Song.mp3" 与 "My_Song.mp3"）会得到不同哈希；
    /// 同一个文件名在 App 重启、refresh() 重新扫描后哈希不变。
    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}