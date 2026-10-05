#!/usr/bin/env python3
import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

HOLD_TERMS = {
    "respond_to_rapid_attack", "sabai", "trade_to_transform", "multi_threat", "tempo_management",
    "急戦", "さばき", "捌き", "局面を変えるための交換", "複数の狙い", "テンポ管理",
}
INTERNAL_TERMS = {"piece_mobility", "escape_route_control", "attack_attacker"}
FORCED_OVERCLAIM_TERMS = {"唯一の応手", "この手しか", "必然の応手", "強制された応手"}


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--expected-requirement", type=int, default=30)
    p.add_argument("--min-continuity", type=int, default=12)
    return p.parse_args()


def semantic_text(record):
    return " ".join([
        record.get("headline") or "",
        record.get("primaryReason") or "",
        record.get("alternativeOutcome") or "",
        record.get("differenceTiming") or "",
        record.get("opponentOpportunity") or "",
        record.get("exchangeAfter") or "",
        record.get("confidenceNote") or "",
    ]).strip()


def displayed_text(record):
    return " ".join([
        record.get("displayedHeadline") or "",
        record.get("displayedPrimaryReason") or "",
    ]).strip()


def add(blockers, record, code, detail=""):
    blockers.append({
        "id": record.get("id"),
        "gameID": record.get("gameID"),
        "ply": record.get("ply"),
        "code": code,
        "detail": detail,
    })


def main():
    args = parse_args()
    doc = json.loads(Path(args.input).read_text(encoding="utf-8"))
    records = doc.get("records") or []
    requirement = [r for r in records if r.get("group") == "requirement"]
    continuity = [r for r in records if r.get("group") == "continuity"]
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    blockers = []
    coverage = []

    if len(requirement) != args.expected_requirement:
        coverage.append(f"requirement_count={len(requirement)} expected={args.expected_requirement}")
    if len(continuity) < args.min_continuity:
        coverage.append(f"continuity_count={len(continuity)} minimum={args.min_continuity}")
    if len({r.get('id') for r in requirement}) != len(requirement):
        coverage.append("duplicate_requirement_ids")

    for r in records:
        text = semantic_text(r)
        confidence = r.get("comparisonConfidence")
        tone = r.get("tone")
        wording = r.get("wordingStrength")
        used_ids = set(r.get("usedEvidenceIDs") or [])
        withheld_ids = set(r.get("withheldEvidenceIDs") or [])
        used_kinds = set(r.get("usedEvidenceKinds") or [])
        causal_count = int(r.get("causalSectionCount") or 0)

        if r.get("candidateAMove") == r.get("candidateBMove"):
            add(blockers, r, "IDENTICAL_PAIR_MOVES")
        if r.get("pairKind") == "BEST_VS_ACTUAL":
            if r.get("candidateBMove") != r.get("actualMove"):
                add(blockers, r, "BEST_ACTUAL_BINDING_MISMATCH")
            if r.get("candidateAMove") == r.get("actualMove"):
                add(blockers, r, "BEST_ACTUAL_NOT_DISTINCT")
        elif r.get("pairKind") == "TOP1_VS_TOP2":
            if r.get("candidateAMove") != r.get("actualMove"):
                add(blockers, r, "TOP1_ACTUAL_CONTROL_MISMATCH")
        else:
            add(blockers, r, "UNKNOWN_PAIR_KIND", str(r.get("pairKind")))

        if not r.get("comparisonStable") and confidence != "UNRESOLVED":
            add(blockers, r, "UNSTABLE_COMPARISON_RESOLVED_CONFIDENCE", confidence or "")
        if confidence == "UNRESOLVED":
            if tone != "UNRESOLVED":
                add(blockers, r, "UNRESOLVED_TONE_NOT_UNRESOLVED", tone or "")
            if causal_count != 0:
                add(blockers, r, "UNRESOLVED_CAUSAL_WORDING", str(causal_count))
        if confidence == "LOW" and causal_count != 0:
            add(blockers, r, "LOW_CONFIDENCE_CAUSAL_WORDING", str(causal_count))
        if wording == "RANKING_ONLY" and causal_count != 0:
            add(blockers, r, "RANKING_ONLY_CAUSAL_WORDING", str(causal_count))

        if "SCORE_DIFFERENCE" in used_kinds:
            add(blockers, r, "SCORE_EVIDENCE_USED_AS_EXPLANATION")
        overlap = used_ids & withheld_ids
        if overlap:
            add(blockers, r, "WITHHELD_EVIDENCE_REUSED", ",".join(sorted(overlap)))

        for term in HOLD_TERMS:
            if term in text:
                add(blockers, r, "HOLD_CONCEPT_LEAKAGE", term)
        for term in INTERNAL_TERMS:
            if term in text:
                add(blockers, r, "INTERNAL_ID_LEAKAGE", term)
        for term in FORCED_OVERCLAIM_TERMS:
            if term in text:
                add(blockers, r, "PV_FORCED_REPLY_OVERCLAIM", term)

        if r.get("opponentOpportunity") and int(r.get("stableHorizonPly") or 0) < 2:
            add(blockers, r, "OPPONENT_OPPORTUNITY_BEYOND_STABLE_HORIZON")
        if r.get("alternativeOutcome") and int(r.get("stableHorizonPly") or 0) < 1:
            add(blockers, r, "ALTERNATIVE_OUTCOME_WITHOUT_STABLE_HORIZON")

        if len(r.get("headline") or "") > 160:
            add(blockers, r, "HEADLINE_TOO_LONG", str(len(r.get("headline") or "")))
        if len(r.get("primaryReason") or "") > 260:
            add(blockers, r, "PRIMARY_REASON_TOO_LONG", str(len(r.get("primaryReason") or "")))
        if not (r.get("headline") or "").strip() or not (r.get("primaryReason") or "").strip():
            add(blockers, r, "EMPTY_SEMANTIC_EXPLANATION")

    if requirement:
        stable = sum(1 for r in requirement if r.get("comparisonStable"))
        resolved = sum(1 for r in requirement if r.get("comparisonConfidence") != "UNRESOLVED")
        if stable < 8:
            coverage.append(f"insufficient_stable_requirement_comparisons={stable}<8")
        if resolved < 6:
            coverage.append(f"insufficient_resolved_requirement_explanations={resolved}<6")
        phases = Counter(r.get("phase") or "UNKNOWN" for r in requirement)
        for phase in ["OPENING", "MIDDLEGAME", "ENDGAME"]:
            if phases.get(phase, 0) == 0:
                coverage.append(f"missing_phase={phase}")
        profiles = Counter(r.get("evidenceProfile") or "UNKNOWN" for r in requirement)
        for profile in ["BASE_PAIR", "PREVIOUS_REPLY", "EXCHANGE", "FORCING"]:
            if profiles.get(profile, 0) == 0:
                coverage.append(f"missing_evidence_profile={profile}")

    continuity = sorted(continuity, key=lambda r: (r.get("gameID") or "", int(r.get("ply") or 0)))
    previous = None
    max_visible_exact_run = 0
    visible_run = 0
    previous_display = None
    for index, r in enumerate(continuity):
        mode = r.get("presentationMode")
        run_length = int(r.get("presentationRunLength") or 0)
        reset = r.get("presentationResetReasons") or []
        shown = displayed_text(r)
        if index == 0:
            if mode != "STANDARD" or run_length != 1 or not shown:
                add(blockers, r, "FIRST_CONTINUITY_PRESENTATION_INVALID", f"mode={mode} run={run_length}")
        if mode == "CONTINUITY":
            if run_length != 2 or not shown:
                add(blockers, r, "CONTINUITY_MODE_INVALID", f"run={run_length}")
        elif mode == "SUPPRESSED_DUPLICATE":
            if run_length < 3 or shown:
                add(blockers, r, "SUPPRESSED_DUPLICATE_INVALID", f"run={run_length} shown={bool(shown)}")
        elif mode == "STANDARD":
            if index > 0 and run_length != 1:
                add(blockers, r, "STANDARD_RESET_RUN_INVALID", str(run_length))
            if index > 0 and not reset:
                add(blockers, r, "STANDARD_RESET_REASON_MISSING")
            if not shown:
                add(blockers, r, "STANDARD_PRESENTATION_HIDDEN")
        else:
            add(blockers, r, "UNKNOWN_PRESENTATION_MODE", str(mode))

        if shown and shown == previous_display:
            visible_run += 1
        elif shown:
            visible_run = 1
        else:
            visible_run = 0
        max_visible_exact_run = max(max_visible_exact_run, visible_run)
        if max_visible_exact_run >= 3:
            add(blockers, r, "VISIBLE_EXACT_COMPARISON_REPEATED_3_PLUS", str(max_visible_exact_run))
        if shown:
            previous_display = shown
        previous = r

    summary = doc.get("summary") or {}
    if int(summary.get("scoreOnlyCausalUsageCount") or 0) != 0:
        coverage.append("summary_score_only_causal_usage_nonzero")
    if int(summary.get("holdTermLeakageCount") or 0) != 0:
        coverage.append("summary_hold_term_leakage_nonzero")
    if int(summary.get("forcedReplyOverclaimCount") or 0) != 0:
        coverage.append("summary_forced_reply_overclaim_nonzero")

    blocker_counts = Counter(item["code"] for item in blockers)
    confidence_counts = Counter(r.get("comparisonConfidence") or "UNKNOWN" for r in requirement)
    pair_counts = Counter(r.get("pairKind") or "UNKNOWN" for r in requirement)
    presentation_counts = Counter(r.get("presentationMode") or "UNKNOWN" for r in continuity)
    machine_pass = not blockers and not coverage

    result = {
        "schemaVersion": 1,
        "stage": "Build19-V Independent Real-game / Semantic Validation",
        "machineVerdict": "PASS" if machine_pass else "FAIL",
        "requirementRecords": len(requirement),
        "continuityRecords": len(continuity),
        "comparisonStableRequirementRecords": sum(1 for r in requirement if r.get("comparisonStable")),
        "resolvedRequirementExplanations": sum(1 for r in requirement if r.get("comparisonConfidence") != "UNRESOLVED"),
        "confidenceDistribution": dict(sorted(confidence_counts.items())),
        "pairKindDistribution": dict(sorted(pair_counts.items())),
        "presentationModeDistribution": dict(sorted(presentation_counts.items())),
        "blockingIssueCount": len(blockers),
        "blockingCategoryCounts": dict(sorted(blocker_counts.items())),
        "coverageFailures": coverage,
        "maxVisibleExactComparisonRun": max_visible_exact_run,
        "humanSemanticReviewRequired": True,
    }
    (out / "BUILD19_V_MACHINE_AUDIT_20261005.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (out / "BUILD19_V_BLOCKING_RECORDS_20261005.json").write_text(
        json.dumps(blockers, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    md = [
        "# Build19-V Human Semantic Review Candidates",
        "",
        f"Machine verdict: **{'PASS' if machine_pass else 'FAIL'}**",
        f"Requirement records: {len(requirement)}",
        f"Continuity records: {len(continuity)}",
        "",
        "## Requirement-linked real-game comparisons",
        "",
        "| id | game | ply | pair | A/B | stable | confidence | dominant | headline | primary reason | alt/outcome |",
        "|---|---|---:|---|---|---|---|---|---|---|---|",
    ]
    for r in requirement:
        def cell(value):
            return str(value or "-").replace("|", "\\|").replace("\n", " ")
        extra = " / ".join(x for x in [r.get("alternativeOutcome"), r.get("opponentOpportunity"), r.get("exchangeAfter")] if x)
        md.append(
            f"| {cell(r.get('id'))} | {cell(r.get('gameID'))} | {r.get('ply')} | {cell(r.get('pairKind'))} | "
            f"{cell(r.get('candidateAMove'))} / {cell(r.get('candidateBMove'))} | {r.get('comparisonStable')} | "
            f"{cell(r.get('comparisonConfidence'))} | {cell(r.get('dominantDifferenceKind'))} | "
            f"{cell(r.get('headline'))} | {cell(r.get('primaryReason'))} | {cell(extra)} |"
        )
    md += [
        "",
        "## Contiguous presentation audit",
        "",
        "| id | ply | confidence | mode | run | reset | displayed |",
        "|---|---:|---|---|---:|---|---|",
    ]
    for r in continuity:
        def cell2(value):
            return str(value or "-").replace("|", "\\|").replace("\n", " ")
        md.append(
            f"| {cell2(r.get('id'))} | {r.get('ply')} | {cell2(r.get('comparisonConfidence'))} | "
            f"{cell2(r.get('presentationMode'))} | {r.get('presentationRunLength')} | "
            f"{cell2(','.join(r.get('presentationResetReasons') or []))} | {cell2(displayed_text(r))} |"
        )
    (out / "BUILD19_V_HUMAN_SEMANTIC_REVIEW_CANDIDATES_20261005.md").write_text(
        "\n".join(md) + "\n", encoding="utf-8"
    )

    print(f"BUILD19_V_MACHINE_VERDICT={'PASS' if machine_pass else 'FAIL'}")
    print(f"requirement_records={len(requirement)} continuity_records={len(continuity)}")
    print(f"stable_requirement={result['comparisonStableRequirementRecords']} resolved_requirement={result['resolvedRequirementExplanations']}")
    print(f"confidence_distribution={dict(confidence_counts)}")
    print(f"pair_kind_distribution={dict(pair_counts)}")
    print(f"presentation_modes={dict(presentation_counts)}")
    print(f"blocking_issues={len(blockers)} coverage_failures={len(coverage)}")
    print("=== BUILD19_V_HUMAN_REVIEW_ROWS ===")
    for r in requirement:
        extra = " | ".join(x for x in [r.get("alternativeOutcome"), r.get("opponentOpportunity"), r.get("exchangeAfter")] if x)
        print(
            f"{r['id']} game={r['gameID']} ply={r['ply']} pair={r['pairKind']} "
            f"moves={r['candidateAMove']}/{r['candidateBMove']} stable={r['comparisonStable']} "
            f"confidence={r['comparisonConfidence']} dominant={r.get('dominantDifferenceKind')} :: "
            f"{r['headline']} || {r['primaryReason']} || {extra}"
        )
    print("=== BUILD19_V_CONTINUITY_ROWS ===")
    for r in continuity:
        print(
            f"{r['id']} ply={r['ply']} conf={r['comparisonConfidence']} mode={r['presentationMode']} "
            f"run={r['presentationRunLength']} reset={','.join(r.get('presentationResetReasons') or [])} :: {displayed_text(r)}"
        )
    if not machine_pass:
        for item in blockers[:50]:
            print(f"BLOCKER {item}", file=sys.stderr)
        for item in coverage:
            print(f"COVERAGE {item}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
