import Foundation
import ShogiCoachCore

struct ContextKnowledgeRuntime {
    let engine: MoveContextEngine
    let loadStatus: String
    let sourceIDs: [String]
    let recordCount: Int
}

enum ContextKnowledgeStore {
    static func load(bundle: Bundle = .main) -> ContextKnowledgeRuntime {
        guard let url = bundle.url(forResource: "context-knowledge", withExtension: "json") else {
            return ContextKnowledgeRuntime(engine: MoveContextEngine(), loadStatus: "missing", sourceIDs: [], recordCount: 0)
        }
        do {
            let data = try Data(contentsOf: url)
            let document = try JSONDecoder().decode(ContextKnowledgeDocument.self, from: data)
            guard document.schemaVersion == 1 else {
                return ContextKnowledgeRuntime(engine: MoveContextEngine(), loadStatus: "unsupported_schema_\(document.schemaVersion)", sourceIDs: document.sources.map(\.sourceID).sorted(), recordCount: document.records.count)
            }
            let provider = CompactMoveContextKnowledgeProvider(document: document)
            return ContextKnowledgeRuntime(engine: MoveContextEngine(knowledgeProvider: provider), loadStatus: "PASS", sourceIDs: document.sources.map(\.sourceID).sorted(), recordCount: document.records.count)
        } catch {
            return ContextKnowledgeRuntime(engine: MoveContextEngine(), loadStatus: "decode_error", sourceIDs: [], recordCount: 0)
        }
    }
}
