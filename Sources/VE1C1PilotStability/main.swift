import Foundation
import ShogiCoachCore

// Report-only invocation of the frozen VE1-B stability classifier.
// C1 semantic certainty is separate; this must never promote confirmedPV.
struct PilotStability {
    enum Invalid: Error {
        case input(String)
    }

    static func object(_ value: Any?, _ name: String) throws -> [String: Any] {
        guard let value = value as? [String: Any] else { throw Invalid.input(name) }
        return value
    }
    static func objects(_ value: Any?, _ name: String) throws -> [[String: Any]] {
        guard let value = value as? [[String: Any]] else { throw Invalid.input(name) }
        return value
    }
    static func string(_ value: Any?, _ name: String) throws -> String {
        guard let value = value as? String else { throw Invalid.input(name) }
        return value
    }
    static func int(_ value: Any?, _ name: String) throws -> Int {
        guard let value = value as? Int else { throw Invalid.input(name) }
        return value
    }
    static func line(_ search: [String: Any], _ name: String) throws -> [String: Any] {
        let s=try objects(search["selectedSnapshot"], name + ":snapshot")
        guard let first=s.first else {throw Invalid.input(name + ":empty")}
        return first
    }
    static func move(_ l: [String: Any], _ name: String) throws -> String {
        guard let pv=l["pv"] as? [String], let root=pv.first else {
            throw Invalid.input(name + ":pv")
        }
        return root
    }
    static func pv(_ l: [String: Any], _ name: String) throws -> [String] {
        guard let v=l["pv"] as? [String], !v.isEmpty else {
            throw Invalid.input(name + ":pv")
        }
        return v
    }
    static func score(_ l: [String: Any], _ name: String) throws -> (String,Int) {
        let k=try string(l["scoreKind"],name+":kind")
        let v=try int(l["scoreValue"],name+":value")
        switch k {
        case "cp": return ("cp",v)
        case "mate": return (v>=0 ? "mate_win":"mate_loss",v)
        default: throw Invalid.input(name+":score_kind")
        }
    }
    static func lossCp(best: [String: Any], actual: [String: Any]) throws -> Int? {
        let bm=try move(best,"best")
        let am=try move(actual,"actual")
        if bm==am{return 0}
        let (bk,bv)=try score(best,"best")
        let (ak,av)=try score(actual,"actual")
        if bk=="cp" && ak=="cp" && bv>=av{return bv-av}
        return nil
    }
    static func target(_ search:[String:Any], _ wanted:String, _ label:String) throws {
        let moves=search["searchMoves"] as? [String] ?? []
        let returned=try string(search["bestmove"],label+":bestmove")
        let root=try move(try line(search,label),label)
        guard moves==[wanted] && returned==wanted && root==wanted else {
            throw Invalid.input(label+":searchmoves_target_mismatch")
        }
    }
    static func gather(_ pos:[String:Any]) throws -> [String:Any] {
        let pid=try string(pos["position_id"],"position_id")
        let app=try object(pos["app"],pid+":app")
        let discovery=try objects(app["discoveries"],pid+":discovery")
        let comparisons=try objects(app["comparisons"],pid+":comparison")
        let actual=try string(pos["actual_move"],pid+":actual")
        let recommended=try string(app["recommendedMove"],pid+":recommended")
        guard discovery.count==3 && comparisons.count==3 else {
            throw Invalid.input(pid+":tier_count")
        }
        var evidence:[VE1BStabilityEvidenceTier]=[]
        for i in 0..<3 {
            let budget=[50000,100000,200000][i]
            let dis=discovery[i]
            let cmp=comparisons[i]
            guard try int(dis["nodeBudget"],pid+":node")==budget &&
                int(cmp["nodeBudget"] as Any, pid+":comparison_nodes") == budget else {
                    throw Invalid.input(pid+":node_tiers")
            }
            let d=try line(dis,pid+":dis")
            let bestSearch=try object(cmp["bestSearch"],pid+":best")
            let actualSearch=try object(cmp["actualSearch"],pid+":actual")
            try target(bestSearch,recommended,pid+":best")
            try target(actualSearch,actual,pid+":actual")
            let b=try line(bestSearch,pid+":bestLine")
            let a=try line(actualSearch,pid+":actualLine")
            let bs=try score(b,pid+":bestScore")
            let ass=try score(a,pid+":actualScore")
            let inversion=cmp["comparisonInversion"] as? Bool ?? false
            let top=try move(d,pid+":candidate")
            let row=VE1BStabilityEvidenceTier(
                nodeBudget:budget,
                candidateTopMove:top,
                candidateTopBoundKind:try string(d["boundKind"],pid+":candBound"),
                bestMove:try move(b,pid+":bestMove"),
                bestScoreKind:bs.0,
                bestScoreValue:bs.1,
                bestBoundKind:try string(b["boundKind"],pid+":bestBound"),
                bestPV:try pv(b,pid+":bestPV"),
                actualMove:try move(a,pid+":actualMove"),
                actualScoreKind:ass.0,
                actualScoreValue:ass.1,
                actualBoundKind:try string(a["boundKind"],pid+":actualBound"),
                actualPV:try pv(a,pid+":actualPV"),
                lossCp:try lossCp(best:b,actual:a),
                comparisonInversion:inversion
            )
            evidence.append(row)
        }
        let classified=VE1BStabilityReclassifier.assess(
            evidence:evidence,rules:.ve1bCalibration
        )
        let state=classified.assessment
        return [
            "position_id":pid,
            "VE1BStabilityState":state.state.rawValue,
            "VE1BConfirmedBestPVPrefix":state.confirmedBestPVPrefix,
            "VE1BConfirmedActualPVPrefix":state.confirmedActualPVPrefix,
            "convergenceBudgets":state.convergenceBudgets,
            "distinctQualifyingBudgets":state.distinctQualifyingBudgets,
            "earlierConflictObserved":state.earlierConflictObserved,
            "tierQualifications":classified.tierClassifications.map {
                ["nodeBudget":$0.nodeBudget,
                 "qualifiesForStability":$0.qualifiesForStability,
                 "conclusionGroup":$0.conclusionGroup,
                 "unstableReasons":$0.unstableReasons] as [String:Any]
            },
            "VE1BStabilityIsNotC1PlayedCertainty":true
        ]
    }
    static func run(_ doc:[String:Any]) throws -> [String:Any] {
        guard try string(doc["result_sha256"],"result_sha256") ==
            "860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea"
        else {throw Invalid.input("frozen_result_identity")}
        let positions=try objects(doc["positions"],"positions")
        guard positions.count==16 else {throw Invalid.input("expected_16")}
        let rows=try positions.map(gather)
        let stable=rows.filter {$0["VE1BStabilityState"] as? String=="stable"}
        return [
            "schema_version":"ve1c1-frozen-VE1B-stability-report-only-v1",
            "status":"REPORT_ONLY",
            "frozen_result_sha256":doc["result_sha256"]!,
            "position_count":positions.count,
            "stable_count":stable.count,
            "stable_ids":stable.compactMap {$0["position_id"] as? String},
            "rows":rows,
            "explicit_non_promotion":true
        ]
    }
}

do {
    guard CommandLine.arguments.count==3 else {
        throw PilotStability.Invalid.input("Usage: VE1C1PilotStability pilot-result.json stability.json")
    }
    let input=URL(fileURLWithPath:CommandLine.arguments[1])
    let output=URL(fileURLWithPath:CommandLine.arguments[2])
    let bytes=try Data(contentsOf:input)
    let json=try JSONSerialization.jsonObject(with:bytes)
    let doc=try PilotStability.object(json,"root")
    let report=try PilotStability.run(doc)
    try FileManager.default.createDirectory(at:output.deletingLastPathComponent(),withIntermediateDirectories:true)
    let blob=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try blob.write(to:output,options:.atomic)
    print(String(data:blob,encoding:.utf8) ?? "")
} catch {
    fatalError("VE1C1PilotStability failure: \(error)")
}
