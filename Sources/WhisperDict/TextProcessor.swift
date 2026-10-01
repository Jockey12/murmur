import Foundation

enum TextProcessor {
    static func process(_ text: String, removeFillers: Bool = false) -> String {
        var result = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        result = result.replacingOccurrences(of: #"\[(?:BLANK_AUDIO|MUSIC|APPLAUSE)\]"#, with: "", options: [.regularExpression, .caseInsensitive])
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        if removeFillers { result = result.replacingOccurrences(of: #"\b(?:um+|uh+|erm+)\b"#, with: "", options: [.regularExpression, .caseInsensitive]).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
        guard let first = result.first else { return result }
        result.replaceSubrange(result.startIndex...result.startIndex, with: String(first).uppercased())
        if !result.isEmpty && !result.last!.isPunctuation { result.append(".") }
        return result
    }
}
