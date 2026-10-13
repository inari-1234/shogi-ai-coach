#!/usr/bin/env python3
from __future__ import annotations

from typing import Any, Iterable


def _rank(info: dict[str, Any]) -> int:
    value = info.get("multipv", 1)
    return int(value) if isinstance(value, int) else 1


def _depth(info: dict[str, Any]) -> int | None:
    value = info.get("depth")
    return int(value) if isinstance(value, int) else None


def _nodes(info: dict[str, Any]) -> int | None:
    value = info.get("nodes")
    return int(value) if isinstance(value, int) else None


def _time_ms(info: dict[str, Any]) -> int | None:
    value = info.get("time")
    if value is None:
        value = info.get("timeMs")
    return int(value) if isinstance(value, int) else None


def _pv(info: dict[str, Any]) -> list[str]:
    value = info.get("pv")
    return list(value) if isinstance(value, list) else []


def _score_kind(info: dict[str, Any]) -> str | None:
    nested = info.get("score")
    if isinstance(nested, dict):
        value = nested.get("type")
        return str(value) if value is not None else None
    value = info.get("scoreKind")
    return str(value) if value is not None else None


def _score_value(info: dict[str, Any]) -> Any:
    nested = info.get("score")
    if isinstance(nested, dict):
        return nested.get("value")
    return info.get("scoreValue")


def _is_exact(info: dict[str, Any]) -> bool:
    nested = info.get("score")
    if isinstance(nested, dict):
        return nested.get("bound") is None
    return info.get("boundKind") == "exact"


def _is_candidate_row(info: dict[str, Any], required_multipv: int) -> bool:
    rank = _rank(info)
    return (
        _depth(info) is not None
        and 1 <= rank <= required_multipv
        and _score_kind(info) is not None
        and bool(_pv(info))
    )


def frozen_selector_snapshot(
    observations: Iterable[dict[str, Any]], required_multipv: int
) -> list[dict[str, Any]] | None:
    """Reproduce the frozen 8daf78c USICompletedIterationSelector behavior."""
    if required_multipv <= 0:
        return None
    indexed = [
        (index, info)
        for index, info in enumerate(observations)
        if _is_candidate_row(info, required_multipv) and _is_exact(info)
    ]
    depths = sorted({_depth(info) for _, info in indexed if _depth(info) is not None}, reverse=True)
    for depth in depths:
        snapshot: list[dict[str, Any]] = []
        for rank in range(1, required_multipv + 1):
            candidates = [
                (index, info)
                for index, info in indexed
                if _depth(info) == depth and _rank(info) == rank
            ]
            if not candidates:
                break
            _, selected = max(
                candidates,
                key=lambda item: (
                    _nodes(item[1]) or 0,
                    _time_ms(item[1]) or 0,
                    item[0],
                ),
            )
            snapshot.append(selected)
        else:
            return sorted(snapshot, key=_rank)
    return None


def deepest_exact_output_block(
    observations: Iterable[dict[str, Any]], required_multipv: int
) -> list[dict[str, Any]] | None:
    """Return the deepest coherent completed MultiPV output block.

    A block is affirmative evidence only when its candidate rows are one ordered
    rank 1..N cohort with identical depth, nodes, and time, all exact. Distinct
    root moves are checked as an integrity consequence; a duplicate makes the
    cohort unusable rather than becoming the primary definition of completion.
    """
    if required_multipv <= 0:
        return None

    rows = [
        (index, info)
        for index, info in enumerate(observations)
        if _is_candidate_row(info, required_multipv)
    ]
    blocks: list[tuple[int, int, int, int, list[dict[str, Any]]]] = []

    for start in range(0, len(rows) - required_multipv + 1):
        window = rows[start : start + required_multipv]
        cohort = [info for _, info in window]
        if [_rank(info) for info in cohort] != list(range(1, required_multipv + 1)):
            continue

        depths = {_depth(info) for info in cohort}
        nodes = {_nodes(info) for info in cohort}
        times = {_time_ms(info) for info in cohort}
        if len(depths) != 1 or None in depths:
            continue
        if len(nodes) != 1 or None in nodes:
            continue
        if len(times) != 1 or None in times:
            continue
        if not all(_is_exact(info) for info in cohort):
            continue

        root_moves = [_pv(info)[0] for info in cohort]
        if len(set(root_moves)) != required_multipv:
            continue

        depth = next(iter(depths))
        node_count = next(iter(nodes))
        time_ms = next(iter(times))
        blocks.append((depth, node_count, time_ms, window[-1][0], cohort))

    if not blocks:
        return None
    return max(blocks, key=lambda block: block[:4])[4]


def snapshot_full_signature(snapshot: list[dict[str, Any]] | None) -> Any:
    if snapshot is None:
        return None
    return [
        (
            _depth(info),
            _rank(info),
            _nodes(info),
            _time_ms(info),
            _score_kind(info),
            _score_value(info),
            _is_exact(info),
            tuple(_pv(info)),
        )
        for info in snapshot
    ]


def snapshot_payload_signature(snapshot: list[dict[str, Any]] | None) -> Any:
    if snapshot is None:
        return None
    return [
        (
            _rank(info),
            _score_kind(info),
            _score_value(info),
            tuple(_pv(info)),
        )
        for info in snapshot
    ]


def snapshot_root_moves(snapshot: list[dict[str, Any]] | None) -> list[str] | None:
    if snapshot is None:
        return None
    return [_pv(info)[0] for info in snapshot]


def snapshot_scores(snapshot: list[dict[str, Any]] | None) -> list[tuple[str | None, Any]] | None:
    if snapshot is None:
        return None
    return [(_score_kind(info), _score_value(info)) for info in snapshot]


def snapshot_brief(snapshot: list[dict[str, Any]] | None) -> Any:
    if snapshot is None:
        return None
    return [
        {
            "depth": _depth(info),
            "multipv": _rank(info),
            "nodes": _nodes(info),
            "time_ms": _time_ms(info),
            "move": _pv(info)[0],
            "score_kind": _score_kind(info),
            "score_value": _score_value(info),
        }
        for info in snapshot
    ]
