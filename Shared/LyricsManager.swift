import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum LyricsManager {
    static func parse(_ content: String) -> [LyricLine] {
        var result: [LyricLine] = []
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        for rawLine in content.components(separatedBy: .newlines) {
            let ns = rawLine as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: rawLine, range: range),
                  match.numberOfRanges >= 5 else { continue }
            let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
            let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0
            let fractionText = match.range(at: 3).location == NSNotFound ? "0" : ns.substring(with: match.range(at: 3))
            let fraction = Double("0." + fractionText) ?? 0
            let text = ns.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
            result.append(LyricLine(time: minutes * 60 + seconds + fraction, text: text))
        }
        return result.sorted { $0.time < $1.time }
    }

    static func load(for fileName: String) -> [LyricLine] {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(stem + ".lrc")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func index(at time: TimeInterval, in lines: [LyricLine]) -> Int {
        guard !lines.isEmpty else { return 0 }
        return lines.lastIndex(where: { $0.time <= time }) ?? 0
    }
}
