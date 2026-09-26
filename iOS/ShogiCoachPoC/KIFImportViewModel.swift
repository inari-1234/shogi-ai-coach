import Foundation
import ShogiCoachCore

@MainActor
final class KIFImportViewModel: ObservableObject {
    @Published private(set) var status = "未読込"
    @Published private(set) var summary = ""
    @Published private(set) var game: KIFGame?

    func importFile(_ url: URL) async {
        status = "読込中"
        summary = ""
        game = nil

        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            let imported = try KIFParser.parse(data: data)
            game = imported
            status = "KIF PASS"

            let first = imported.moves.first?.usi ?? "-"
            let last = imported.moves.last?.usi ?? "-"
            let sente = imported.metadata["先手"] ?? "-"
            let gote = imported.metadata["後手"] ?? "-"
            summary = [
                "file: \(url.lastPathComponent)",
                "moves: \(imported.moves.count)",
                "positions: \(imported.moves.count)",
                "players: \(sente) / \(gote)",
                "first: \(first)",
                "last: \(last)",
                "result: \(imported.termination ?? "-")"
            ].joined(separator: "\n")
        } catch {
            status = "KIF 未PASS"
            summary = error.localizedDescription
        }
    }
}
