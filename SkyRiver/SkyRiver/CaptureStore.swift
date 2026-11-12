import Foundation
import Combine

struct CapturedRequest: Identifiable, Codable, Hashable {
    var id = UUID()
    var time = Date()
    var url: String
    var method: String
    var body: String
    var status: Int
    var response: String

    var path: String {
        guard let components = URLComponents(string: url) else { return url }
        let query = components.query.map { "?\($0)" } ?? ""
        return (components.path.isEmpty ? "/" : components.path) + query
    }

    var host: String {
        URLComponents(string: url)?.host ?? ""
    }

    var statusText: String {
        switch status {
        case -1: return "网络错误"
        case -2: return "表单提交"
        case -3: return "时序探测"
        default: return "\(status)"
        }
    }
}

final class CaptureStore: ObservableObject {
    @Published private(set) var items: [CapturedRequest] = []
    @Published var isRecording = true

    private var seen = Set<String>()

    func ingest(_ raws: [[String: Any]]) {
        guard isRecording, !raws.isEmpty else { return }

        var appended: [CapturedRequest] = []
        for raw in raws {
            let url = (raw["url"] as? String) ?? ""
            guard !url.isEmpty, url.contains("skyriver.top") || url.hasPrefix("/") else { continue }

            let method = (raw["method"] as? String) ?? "?"
            let body = (raw["body"] as? String) ?? ""
            let statusValue = raw["status"]
            let status: Int
            if let number = statusValue as? NSNumber {
                status = number.intValue
            } else if let intValue = statusValue as? Int {
                status = intValue
            } else {
                status = 0
            }
            let response = (raw["resp"] as? String) ?? ""

            let key = "\(method)|\(url)|\(body)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            appended.append(CapturedRequest(url: url,
                                            method: method,
                                            body: body,
                                            status: status,
                                            response: response))
        }
        if !appended.isEmpty {
            items.append(contentsOf: appended)
        }
    }

    func clear() {
        items.removeAll()
        seen.removeAll()
    }

    func exportJSON() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(items) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("skyriver-endpoints.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    func exportText() -> String {
        items.map { item in
            """
            \(item.method) \(item.url)
            状态: \(item.statusText)
            请求体: \(item.body.isEmpty ? "-" : item.body)
            响应: \(item.response.isEmpty ? "-" : String(item.response.prefix(600)))
            """
        }
        .joined(separator: "\n\n---\n\n")
    }
}
