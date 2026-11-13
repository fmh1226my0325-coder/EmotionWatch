
import Foundation

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

enum LyricsManager {

    static func parse(_ content: String) -> [LyricLine] {
        var result: [LyricLine] = []

        let pattern = #"\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let ns = rawLine as NSString
            let range = NSRange(location: 0, length: ns.length)

            let matches = regex.matches(
                in: rawLine,
                range: range
            )

            guard !matches.isEmpty else { continue }

            let text = regex.stringByReplacingMatches(
                in: rawLine,
                range: range,
                withTemplate: ""
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            for match in matches {
                let minutes = Double(ns.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: match.range(at: 2))) ?? 0

                let fractionText: String
                if match.range(at: 3).location == NSNotFound {
                    fractionText = ""
                } else {
                    fractionText = ns.substring(with: match.range(at: 3))
                }

                let fraction: Double
                if fractionText.isEmpty {
                    fraction = 0
                } else {
                    fraction = (Double(fractionText) ?? 0) /
                        pow(10, Double(fractionText.count))
                }

                let timestamp = minutes * 60 + seconds + fraction

                result.append(
                    LyricLine(time: timestamp, text: text)
                )
            }
        }

        return result.sorted {
            $0.time < $1.time
        }
    }

    static func load(for fileName: String) -> [LyricLine] {
        let stem = URL(fileURLWithPath: fileName)
            .deletingPathExtension()
            .lastPathComponent

        let directory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let candidates = [
            directory.appendingPathComponent(stem + ".lrc"),
            directory.appendingPathComponent(stem + ".LRC")
        ]

        for url in candidates {
            guard let data = try? Data(contentsOf: url) else {
                continue
            }

            if let text = String(data: data, encoding: .utf8) {
                return parse(text)
            }

            if let text = String(data: data, encoding: .utf16) {
                return parse(text)
            }
        }

        return []
    }

    static func index(
        at time: TimeInterval,
        in lines: [LyricLine]
    ) -> Int {
        guard !lines.isEmpty else { return 0 }

        return lines.lastIndex {
            $0.time <= time
        } ?? 0
    }
}
