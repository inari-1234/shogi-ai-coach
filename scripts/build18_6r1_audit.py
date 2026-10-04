#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

SAFE_CONCEPTS = {"piece_mobility", "escape_route_control", "attack_attacker"}
DISABLED_TRIGGERS = {"VERIFIED_SEQUENCE_TIMING", "FORMATION_WINDOW", "ENDGAME_URGENCY"}
HELD_TERMS = {
    "respond_to_rapid_attack", "sabai", "trade_to_transform", "multi_threat", "tempo_management",
    "急戦", "さばき", "捌き", "局面を変えるための交換", "複数の狙い", "テンポ管理",
}
SHIKENBISHA_TERMS = {"振り飛車", "四間飛車", "三間飛車", "向かい飛車", "中飛車", "さばき", "捌き"}

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output-dir", required=True)
    p.add_argument("--min-games", type=int, required=True)
    p.add_argument("--min-positions", type=int, required=True)
    p.add_argument("--label", default="full")
    return p.parse_args()

def stable_key(record):
    raw = f"{record.get('gameID','')}:{record.get('ply',0)}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()

def full_text(record):
    return " ".join([
        record.get("primaryExplanation") or "",
        record.get("whyNow") or "",
        record.get("conceptSupplementText") or "",
    ]).strip()

def semantic_text(record):
    return " ".join([
        record.get("rawPrimaryExplanation") or record.get("primaryExplanation") or "",
        record.get("rawWhyNow") or record.get("whyNow") or "",
        record.get("rawConceptSupplementText") or record.get("conceptSupplementText") or "",
    ]).strip()

def normalized_text(value):
    value = (value or "").strip().lower()
    value = re.sub(r"[1-9][a-i]", "<sq>", value)
    value = re.sub(r"\d+", "<n>", value)
    value = re.sub(r"[\s、。・,:;（）()「」『』]+", "", value)
    return value

def add(counter, key):
    counter[key] += 1

def classify_blockers(record):
    cats = []
    trigger = record.get("whyNowTrigger")
    confidence = record.get("confidence")
    mode = record.get("whyNowVerbalizationMode")
    intent = record.get("primaryIntent")
    source_evidence = record.get("whyNowSourceEvidenceIDs") or []
    selected_ids = record.get("selectedIntentEvidenceIDs") or []
    selected_kinds = record.get("selectedIntentEvidenceKinds") or []
    non_geometry = int(record.get("selectedIntentNonGeometryEvidenceCount") or 0)
    claims = set(record.get("whyNowClaimTypes") or [])
    text = semantic_text(record)
    concept_id = record.get("conceptID")

    if trigger in DISABLED_TRIGGERS:
        cats.append("UNSUPPORTED_SPECIALIZED_TRIGGER")
    if record.get("heldConceptLeakage") or any(term in text for term in HELD_TERMS):
        cats.append("HELD_CONCEPT_LEAKAGE")
    if confidence in {"low", "unresolved"} and mode in {"ASSERTIVE", "MEASURED"}:
        cats.append("LOW_UNRESOLVED_ASSERTIVE_PURPOSE")
    if intent != "unresolved" and confidence in {"high", "medium"} and non_geometry == 0:
        cats.append("UNSUPPORTED_PURPOSE")
        if selected_kinds and set(selected_kinds) <= {"geometry"}:
            cats.append("GEOMETRY_ONLY_PURPOSE")
    if trigger in {"DIRECT_PREVIOUS_MOVE", "EXCHANGE_SEQUENCE"}:
        if not record.get("previousMove") or not source_evidence:
            cats.append("FALSE_PREVIOUS_MOVE_CAUSALITY")
    if SAFE_CONCEPTS.intersection(selected_ids):
        cats.append("EFFECT_TO_INTENT")
    if "OUTCOME" in claims and trigger != "EXCHANGE_SEQUENCE" and not source_evidence:
        cats.append("OUTCOME_TO_REASON")
    if concept_id and concept_id not in SAFE_CONCEPTS:
        cats.append("UNSUPPORTED_SPECIALIZED_CONCEPT")
    if any(term in text for term in SHIKENBISHA_TERMS) and not record.get("shikenbishaHeuristic"):
        cats.append("SHIKENBISHA_OVERCLAIM")

    if "詰み" in text and "ev_forced_mate" not in selected_ids and intent == "mating_attack":
        cats.append("FICTITIOUS_MATE")
    if "詰めろ" in text and not ({"ev_threatmate", "ev_threatmate_defense"} & set(selected_ids)):
        if intent in {"threatmate", "threatmate_defense"}:
            cats.append("FICTITIOUS_THREATMATE")

    for legacy in record.get("falseExplanationCategories") or []:
        cats.append(f"BUILD17_{legacy}")

    return sorted(set(cats))

def repetition_metrics(records):
    by_game = defaultdict(list)
    for r in records:
        by_game[r.get("gameID","")].append(r)

    redundant_exact_full = 0
    redundant_exact_whynow = 0
    redundant_near_whynow = 0
    legitimate_exact_full = 0
    legitimate_exact_whynow = 0
    max_redundant_full_run = 1
    max_redundant_whynow_run = 1
    same_concept_within3 = 0
    same_concept_consecutive = 0
    continuity_count = 0
    suppressed_count = 0
    reset_count = 0
    policy_violations = []

    for game_id, game_records in by_game.items():
        game_records.sort(key=lambda x: x.get("ply", 0))
        full_run = 1
        why_run = 1
        last_concept_ply = {}
        previous = None

        for r in game_records:
            concept = r.get("conceptID")
            ply = int(r.get("ply", 0))
            mode = r.get("presentationMode") or "STANDARD"
            if mode == "CONTINUITY":
                continuity_count += 1
            elif mode == "SUPPRESSED_DUPLICATE":
                suppressed_count += 1
            if r.get("repetitionResetReasons"):
                reset_count += 1

            if concept:
                if concept in last_concept_ply and ply - last_concept_ply[concept] <= 3:
                    same_concept_within3 += 1
                last_concept_ply[concept] = ply

            if previous is not None:
                previous_ply = int(previous.get("ply", 0))
                is_true_consecutive_ply = ply == previous_ply + 1
                same_signature = (
                    bool(r.get("repetitionSemanticSignature"))
                    and r.get("repetitionSemanticSignature") == previous.get("repetitionSemanticSignature")
                )
                current_full = full_text(r)
                previous_full = full_text(previous)
                current_why = (r.get("whyNow") or "").strip()
                previous_why = (previous.get("whyNow") or "").strip()
                same_full = bool(current_full) and current_full == previous_full
                same_why = bool(current_why) and current_why == previous_why
                near_why = (
                    bool(current_why) and bool(previous_why)
                    and normalized_text(current_why) == normalized_text(previous_why)
                )

                if is_true_consecutive_ply:
                    if mode == "CONTINUITY":
                        if not same_signature or int(r.get("repetitionEquivalentRunLength") or 0) != 2:
                            policy_violations.append({"gameID": game_id, "ply": ply, "type": "INVALID_CONTINUITY_STATE"})
                        if not current_full:
                            policy_violations.append({"gameID": game_id, "ply": ply, "type": "EMPTY_CONTINUITY_DISPLAY"})
                    elif mode == "SUPPRESSED_DUPLICATE":
                        if not same_signature or int(r.get("repetitionEquivalentRunLength") or 0) < 3:
                            policy_violations.append({"gameID": game_id, "ply": ply, "type": "INVALID_SUPPRESSION_STATE"})
                        if current_full:
                            policy_violations.append({"gameID": game_id, "ply": ply, "type": "SUPPRESSED_DUPLICATE_STILL_VISIBLE"})
                    elif same_signature:
                        policy_violations.append({"gameID": game_id, "ply": ply, "type": "EQUIVALENT_REPEAT_NOT_CONTROLLED"})

                    if same_full:
                        if same_signature:
                            redundant_exact_full += 1
                            full_run += 1
                        else:
                            legitimate_exact_full += 1
                            full_run = 1
                    else:
                        full_run = 1

                    if same_why or near_why:
                        if same_signature:
                            if same_why:
                                redundant_exact_whynow += 1
                            if near_why:
                                redundant_near_whynow += 1
                            why_run += 1
                        else:
                            if same_why:
                                legitimate_exact_whynow += 1
                            why_run = 1
                    else:
                        why_run = 1

                    if concept and concept == previous.get("conceptID"):
                        same_concept_consecutive += 1
                else:
                    full_run = 1
                    why_run = 1

                max_redundant_full_run = max(max_redundant_full_run, full_run)
                max_redundant_whynow_run = max(max_redundant_whynow_run, why_run)

            previous = r

    major = (
        max_redundant_full_run >= 3
        or max_redundant_whynow_run >= 4
        or bool(policy_violations)
    )
    return {
        "sampleNeighborExactFullExplanationCount": redundant_exact_full + legitimate_exact_full,
        "sampleNeighborExactWhyNowCount": redundant_exact_whynow + legitimate_exact_whynow,
        "sampleNeighborNormalizedNearWhyNowCount": redundant_near_whynow + legitimate_exact_whynow,
        "trueConsecutivePlyExactFullExplanationCount": redundant_exact_full,
        "trueConsecutivePlyExactWhyNowCount": redundant_exact_whynow,
        "trueConsecutivePlyNormalizedNearWhyNowCount": redundant_near_whynow,
        "legitimateRepeatedExactFullExplanationCount": legitimate_exact_full,
        "legitimateRepeatedExactWhyNowCount": legitimate_exact_whynow,
        "continuityPresentationCount": continuity_count,
        "suppressedDuplicatePresentationCount": suppressed_count,
        "resetPresentationCount": reset_count,
        "presentationPolicyViolationCount": len(policy_violations),
        "presentationPolicyViolations": policy_violations[:100],
        "sameConceptShownWithin3PlyCount": same_concept_within3,
        "sameConceptShownOnConsecutivePlyCount": same_concept_consecutive,
        "maxTrueConsecutivePlyExactFullExplanationRun": max_redundant_full_run,
        "maxTrueConsecutivePlyNormalizedWhyNowRun": max_redundant_whynow_run,
        "majorRepetitionFailure": major,
        "blockingRule": "Only redundant true-consecutive visible repetitions with an unchanged semantic signature, or an invalid suppression/continuity state, are blocking. Legitimate repeated wording after an explicit reset is reported separately.",
    }

def select_human_sample(records, limit=48):
    ordered = sorted(records, key=stable_key)
    selected = []
    seen = set()

    def take(predicate, tag):
        for r in ordered:
            key = (r.get("gameID"), r.get("ply"))
            if key in seen:
                continue
            if predicate(r):
                item = dict(r)
                item["selectionTag"] = tag
                selected.append(item)
                seen.add(key)
                return

    for phase in ["OPENING", "MIDDLEGAME", "ENDGAME"]:
        take(lambda r, p=phase: r.get("phase") == p, f"phase:{phase}")
    for confidence in ["high", "medium", "low", "unresolved"]:
        take(lambda r, c=confidence: r.get("confidence") == c, f"confidence:{confidence}")
    for trigger in [
        "DIRECT_PREVIOUS_MOVE", "IMMEDIATE_THREAT", "FORCING_TACTIC", "EXCHANGE_SEQUENCE",
        "VERIFIED_SEQUENCE_TIMING", "FORMATION_WINDOW", "ENDGAME_URGENCY", "NONE_IDENTIFIED"
    ]:
        take(lambda r, t=trigger: r.get("whyNowTrigger") == t, f"trigger:{trigger}")
    take(lambda r: bool(r.get("conceptSupplementPresent")), "supplement")
    take(lambda r: not bool(r.get("conceptSupplementPresent")), "no_supplement")
    take(lambda r: int(r.get("intentCandidateCount") or 0) > 1, "multiple_intent")
    take(lambda r: bool(r.get("forcingPosition")), "forcing")
    take(lambda r: bool(r.get("quietOrAmbiguous")), "quiet_or_ambiguous")
    take(lambda r: bool(r.get("shikenbishaHeuristic")), "shikenbisha_heuristic")
    take(
        lambda r: r.get("confidence") in {"low", "unresolved"}
        or r.get("whyNowAuthority") in {"GEOMETRY", "NONE"}
        or int(r.get("intentCandidateCount") or 0) > 1,
        "adversarial_like"
    )
    take(lambda r: r.get("presentationMode") == "CONTINUITY", "repetition_continuity")
    take(lambda r: r.get("presentationMode") == "SUPPRESSED_DUPLICATE", "repetition_suppressed")
    take(lambda r: bool(r.get("repetitionResetReasons")) and r.get("repetitionResetReasons") != ["INITIAL"], "repetition_reset")

    for r in ordered:
        if len(selected) >= limit:
            break
        key = (r.get("gameID"), r.get("ply"))
        if key in seen:
            continue
        item = dict(r)
        item["selectionTag"] = "deterministic_fill"
        selected.append(item)
        seen.add(key)

    return selected

def main():
    args = parse_args()
    src = Path(args.input)
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    doc = json.loads(src.read_text(encoding="utf-8"))
    records = doc.get("records") or []
    games = doc.get("games") or []
    summary = doc.get("summary") or {}

    game_count = int(summary.get("auditedGames") or len(games))
    position_count = int(summary.get("auditedPositions") or len(records))

    phase_counts = Counter(r.get("phase") or "UNKNOWN" for r in records)
    confidence_counts = Counter(r.get("confidence") or "UNKNOWN" for r in records)
    intent_counts = Counter(r.get("primaryIntent") or "UNKNOWN" for r in records)
    trigger_counts = Counter(r.get("whyNowTrigger") or "UNKNOWN" for r in records)
    supplement_count = sum(1 for r in records if r.get("conceptSupplementPresent"))
    multiple_intent_count = sum(1 for r in records if int(r.get("intentCandidateCount") or 0) > 1)
    forcing_count = sum(1 for r in records if r.get("forcingPosition"))
    quiet_count = sum(1 for r in records if r.get("quietOrAmbiguous"))
    shikenbisha_count = sum(1 for r in records if r.get("shikenbishaHeuristic"))

    blocker_counts = Counter()
    blocker_records = []
    for r in records:
        cats = classify_blockers(r)
        if cats:
            for c in cats:
                add(blocker_counts, c)
            blocker_records.append({
                "gameID": r.get("gameID"),
                "ply": r.get("ply"),
                "categories": cats,
                "intent": r.get("primaryIntent"),
                "confidence": r.get("confidence"),
                "trigger": r.get("whyNowTrigger"),
                "explanation": full_text(r),
            })

    repetition = repetition_metrics(records)
    human_candidates = select_human_sample(records)

    automated_blocking_total = sum(blocker_counts.values())
    coverage_failures = []
    if game_count < args.min_games:
        coverage_failures.append(f"games {game_count} < {args.min_games}")
    if position_count < args.min_positions:
        coverage_failures.append(f"positions {position_count} < {args.min_positions}")
    if args.min_positions >= 600:
        for phase in ["OPENING", "MIDDLEGAME", "ENDGAME"]:
            if phase_counts.get(phase, 0) == 0:
                coverage_failures.append(f"phase {phase} has zero coverage")
        if supplement_count == 0:
            coverage_failures.append("concept supplement has zero coverage")
        if supplement_count == position_count:
            coverage_failures.append("no-supplement has zero coverage")
        if trigger_counts.get("NONE_IDENTIFIED", 0) == 0:
            coverage_failures.append("NONE_IDENTIFIED has zero coverage")
        if forcing_count == 0:
            coverage_failures.append("forcing position has zero coverage")
        if quiet_count == 0:
            coverage_failures.append("quiet/ambiguous position has zero coverage")

    result = {
        "schemaVersion": 1,
        "stage": "Build18-6R1 Explanation Repetition Corrective Implementation",
        "label": args.label,
        "source": doc.get("source"),
        "samplingPolicy": doc.get("samplingPolicy"),
        "games": games,
        "summary": {
            "games": game_count,
            "evaluatedPositions": position_count,
            "phaseDistribution": dict(sorted(phase_counts.items())),
            "confidenceDistribution": dict(sorted(confidence_counts.items())),
            "selectedIntentDistribution": dict(sorted(intent_counts.items())),
            "whyNowTriggerDistribution": dict(sorted(trigger_counts.items())),
            "conceptSupplement": supplement_count,
            "noSupplement": position_count - supplement_count,
            "multipleIntentCandidate": multiple_intent_count,
            "forcingPosition": forcing_count,
            "quietOrAmbiguous": quiet_count,
            "shikenbishaHeuristicPositions": shikenbisha_count,
            "blockingCrash": 0,
            "automatedSemanticBlockerEvents": automated_blocking_total,
            "coverageFailures": coverage_failures,
        },
    }

    false_summary = {
        "unsupportedPurpose": blocker_counts.get("UNSUPPORTED_PURPOSE", 0),
        "effectToIntent": blocker_counts.get("EFFECT_TO_INTENT", 0),
        "outcomeToReason": blocker_counts.get("OUTCOME_TO_REASON", 0),
        "falsePreviousMoveCausality": blocker_counts.get("FALSE_PREVIOUS_MOVE_CAUSALITY", 0),
        "geometryOnlyPurpose": blocker_counts.get("GEOMETRY_ONLY_PURPOSE", 0),
        "lowUnresolvedAssertivePurpose": blocker_counts.get("LOW_UNRESOLVED_ASSERTIVE_PURPOSE", 0),
        "shikenbishaOverclaim": blocker_counts.get("SHIKENBISHA_OVERCLAIM", 0),
        "heldConceptLeakage": blocker_counts.get("HELD_CONCEPT_LEAKAGE", 0),
        "unsupportedSpecializedConcept": blocker_counts.get("UNSUPPORTED_SPECIALIZED_CONCEPT", 0),
        "unsupportedSpecializedTrigger": blocker_counts.get("UNSUPPORTED_SPECIALIZED_TRIGGER", 0),
        "fictitiousMate": blocker_counts.get("FICTITIOUS_MATE", 0),
        "fictitiousThreatmate": blocker_counts.get("FICTITIOUS_THREATMATE", 0),
    }

    quality = {
        "schemaVersion": 1,
        "Q1_Groundedness": {
            "automatedStatus": "PASS" if (
                false_summary["unsupportedPurpose"] == 0
                and false_summary["geometryOnlyPurpose"] == 0
                and false_summary["unsupportedSpecializedConcept"] == 0
            ) else "BLOCKER",
        },
        "Q2_Causality": {
            "automatedStatus": "PASS" if false_summary["falsePreviousMoveCausality"] == 0 else "BLOCKER",
        },
        "Q3_LayerCorrectness": {
            "automatedStatus": "PASS" if (
                false_summary["effectToIntent"] == 0 and false_summary["outcomeToReason"] == 0
            ) else "BLOCKER",
        },
        "Q4_UncertaintyCalibration": {
            "automatedStatus": "PASS" if false_summary["lowUnresolvedAssertivePurpose"] == 0 else "BLOCKER",
        },
        "Q5_BeginnerReadability": {"automatedStatus": "MANUAL_REVIEW_REQUIRED"},
        "Q6_ConcisionRedundancy": {
            "automatedStatus": "BLOCKER" if repetition["majorRepetitionFailure"] else "PASS_WITH_MANUAL_REVIEW",
            "repetition": repetition,
        },
        "Q7_ScopeDiscipline": {
            "automatedStatus": "PASS" if (
                false_summary["heldConceptLeakage"] == 0
                and false_summary["shikenbishaOverclaim"] == 0
                and false_summary["fictitiousMate"] == 0
                and false_summary["fictitiousThreatmate"] == 0
            ) else "BLOCKER",
        },
        "humanReviewRequired": True,
    }

    (out / "BUILD18_6R1_REAL_GAME_E2E_RESULTS_20261004.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (out / "BUILD18_6R1_EXPLANATION_QUALITY_AUDIT_20261004.json").write_text(
        json.dumps(quality, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (out / "BUILD18_6R1_REPETITION_AUDIT_20261004.json").write_text(
        json.dumps(repetition, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (out / "BUILD18_6R1_HUMAN_SEMANTIC_REVIEW_CANDIDATES_20261004.json").write_text(
        json.dumps({
            "selectionRule": "deterministic SHA-256 ordering with mandatory stratum-first picks, then deterministic fill",
            "count": len(human_candidates),
            "records": human_candidates,
        }, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    md = [
        "# Build18-6 False Explanation Audit",
        "",
        f"- label: {args.label}",
        f"- games: {game_count}",
        f"- positions: {position_count}",
        f"- automated semantic blocker events: {automated_blocking_total}",
        f"- coverage failures: {len(coverage_failures)}",
        "",
        "## Blocking category counts",
        "",
    ]
    for key in sorted(false_summary):
        md.append(f"- {key}: {false_summary[key]}")
    if blocker_records:
        md += ["", "## Blocking records", ""]
        for item in blocker_records[:100]:
            md.append(
                f"- {item['gameID']} ply {item['ply']}: {','.join(item['categories'])} / "
                f"intent={item['intent']} confidence={item['confidence']} trigger={item['trigger']} / "
                f"{item['explanation']}"
            )
    if coverage_failures:
        md += ["", "## Coverage failures", ""]
        md.extend(f"- {x}" for x in coverage_failures)
    (out / "BUILD18_6R1_FALSE_EXPLANATION_AUDIT_20261004.md").write_text(
        "\n".join(md) + "\n", encoding="utf-8"
    )

    machine_pass = automated_blocking_total == 0 and not coverage_failures and not repetition["majorRepetitionFailure"]
    print(f"build18_6r1_{args.label}_machine_status={'PASS' if machine_pass else 'FAIL'}")
    print(f"games={game_count}")
    print(f"positions={position_count}")
    print(f"automated_semantic_blockers={automated_blocking_total}")
    print(f"major_repetition_failure={str(repetition['majorRepetitionFailure']).lower()}")
    print(f"coverage_failures={len(coverage_failures)}")
    if not machine_pass:
        sys.exit(1)

if __name__ == "__main__":
    main()
