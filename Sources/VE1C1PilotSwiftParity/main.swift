import Foundation
import ShogiCoachCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Frozen Swift parser/selector parity over the *same raw USI* as the natural pilot.
/// C1 coherent-block selection remains a separate downstream check.
enum PilotSwiftParity {
    static func dictionary(_ value: Any?) -> [String: Any]? { value as? [String: Any] }
    static func array(_ value: Any?) -> [[String: Any]]? { value as? [[String: Any]] }
    static func number(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }
    static func nullOrMissing(_ value: Any?) -> Bool { value == nil || value is NSNull }

    static func score(_ info: USIInfo) -> (String?, Int?) {
        switch info.score {
        case .none: return (nil, nil)
        case .centipawn(let value, _): return ("cp", value)
        case .mate(let value, _): return ("mate", value)
        }
    }
    static func same(_ exported: [String: Any], _ parsed: USIInfo) -> Bool {
        let (kind, value) = score(parsed)
        guard exported["rawUSI"] as? String == parsed.rawLine,
              number(exported["multipv"]) == parsed.multipv,
              (nullOrMissing(exported["depth"]) ? parsed.depth == nil : number(exported["depth"]) == parsed.depth),
              (nullOrMissing(exported["seldepth"]) ? parsed.selDepth == nil : number(exported["seldepth"]) == parsed.selDepth),
              (nullOrMissing(exported["scoreKind"]) ? kind == nil : exported["scoreKind"] as? String == kind),
              (nullOrMissing(exported["scoreValue"]) ? value == nil : number(exported["scoreValue"]) == value),
              exported["boundKind"] as? String == (parsed.boundKind?.rawValue ?? "exact"),
              (exported["pv"] as? [String]) == parsed.pv else { return false }
        for (field, actual) in [
            ("nodes", parsed.nodes), ("nps", parsed.nps), ("timeMs", parsed.timeMs)
        ] {
            if let n = actual {
                guard let s = exported[field] as? NSNumber, s.uint64Value == n else { return false }
            } else if !nullOrMissing(exported[field]) {
                return false
            }
        }
        return true
    }
    static func evidence(for search: [String: Any], at path: String, mismatch: inout [[String: Any]], total: inout Int) {
        guard let exported = array(search["observations"]),
              let required = number(search["multiPV"]), required > 0 else {
            mismatch.append(["path": path, "reason": "MISSING_OBSERVATIONS_OR_MULTIPV"])
            return
        }
        var info: [USIInfo] = []
        for (index, item) in exported.enumerated() {
            total += 1
            guard let raw = item["rawUSI"] as? String,
                  !raw.hasPrefix("info string "),
                  let parsed = USIParser.parseInfo(raw) else {
                mismatch.append(["path": path, "observation": index, "reason": "RAW_SWIFT_PARSE_FAILURE"])
                continue
            }
            info.append(parsed)
            if !same(item, parsed) {
                mismatch.append(["path": path, "observation": index, "reason": "FIELD_PARITY"])
            }
        }
        let selected = USICompletedIterationSelector.deepestExactSnapshot(
            observations: info, requiredMultiPV: required
        ) ?? []
        // The C1 coherent guard must not replace the frozen VE1-B selector in parity.
        let stored = array(search["ve1bFrozenSnapshot"]) ?? array(search["selectedSnapshot"]) ?? []
        let frozenRaw = selected.compactMap { $0.rawLine }
        let storedRaw = stored.compactMap { $0["rawUSI"] as? String }
        if frozenRaw != storedRaw {
            mismatch.append(["path": path, "reason": "FROZEN_SELECTOR_PARITY",
                             "selected": frozenRaw.prefix(4).joined(separator: " | "),
                             "stored": storedRaw.prefix(4).joined(separator: " | ")])
        }
    }

    static func run(_ raw: [String: Any]) -> [String: Any] {
        var mismatch: [[String: Any]] = []
        var count = 0
        guard let positions = array(raw["positions"]), positions.count == 16,
              raw["run_kind"] as? String == "excluded_natural_pilot" else {
            return ["status": "FAIL", "mismatch_count": 1, "reason": "NATURAL_PILOT_RESULT_REQUIRED"]
        }
        var searches = 0
        for (i, position) in positions.enumerated() {
            let id = position["position_id"] as? String ?? "p\(i + 1)"
            if let app = dictionary(position["app"]) {
                if let discoveries = array(app["discoveries"]) {
                    for (n, search) in discoveries.enumerated() {
                        searches += 1
                        evidence(for: search, at: "\(id)/app/discovery/\(n)",
                                 mismatch: &mismatch, total: &count)
                    }
                } else { mismatch.append(["path": id, "reason": "APP_DISCOVERIES_MISSING"]) }
                if let comparisons = array(app["comparisons"]) {
                    for (n, pair) in comparisons.enumerated() {
                        for key in ["bestSearch", "actualSearch"] {
                            if let search = dictionary(pair[key]) {
                                searches += 1
                                evidence(for: search, at: "\(id)/app/\(n)/\(key)",
                                         mismatch: &mismatch, total: &count)
                            } else { mismatch.append(["path": id, "reason": "APP_COMPARISON_MISSING_\(key)"]) }
                        }
                    }
                } else { mismatch.append(["path": id, "reason": "APP_COMPARISONS_MISSING"]) }
            } else { mismatch.append(["path": id, "reason": "APP_MISSING"]) }
            if let reference = dictionary(position["reference"]), let budgets = array(reference["budgets"]) {
                for (n, budget) in budgets.enumerated() {
                    if let root = dictionary(budget["root"]) {
                        searches += 1
                        evidence(for: root, at: "\(id)/reference/\(n)/root",
                                 mismatch: &mismatch, total: &count)
                    } else { mismatch.append(["path": id, "reason": "REFERENCE_ROOT_MISSING"]) }
                    for key in ["bestSearch", "actualSearch"] {
                        if let search = dictionary(budget[key]) {
                            searches += 1
                            evidence(for: search, at: "\(id)/reference/\(n)/\(key)",
                                     mismatch: &mismatch, total: &count)
                        }
                    }
                }
            } else { mismatch.append(["path": id, "reason": "REFERENCE_BUDGETS_MISSING"]) }
        }
        return [
            "schema_version": "ve1c1-swift-raw-usi-parity-v1",
            "status": mismatch.isEmpty ? "PASS" : "FAIL",
            "position_count": positions.count,
            "search_count": searches,
            "observation_count": count,
            "mismatch_count": mismatch.count,
            "mismatches": Array(mismatch.prefix(100)),
        ]
    }
}

@main
struct Main {
    static func main() {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: VE1C1PilotSwiftParity pilot-result.json parity.json\n", stderr)
            exit(2)
        }
        do {
            let input = URL(fileURLWithPath: CommandLine.arguments[1])
            let output = URL(fileURLWithPath: CommandLine.arguments[2])
            let data = try Data(contentsOf: input)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                fputs("pilot-result not an object\n", stderr)
                exit(2)
            }
            let result = PilotSwiftParity.run(root)
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let bytes = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try bytes.write(to: output, options: .atomic)
            print(String(data: bytes, encoding: .utf8) ?? "")
            if result["status"] as? String != "PASS" { exit(2) }
        } catch {
            fputs("swift_parity_error: \(error)\n", stderr)
            exit(2)
        }
    }
}
