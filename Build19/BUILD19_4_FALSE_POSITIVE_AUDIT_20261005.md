# Build19-4 False-positive Audit

Date: 2026-10-05
Status: CANDIDATE / VALIDATION PENDING

## Audit purpose

Build19-4 exists specifically to prevent newly available sequence/counterfactual evidence from leaking into unsupported specialized shogi concepts. The primary failure mode is semantic overreach: observing a concrete event and naming a higher-level purpose that the evidence does not prove.

## Concept audits

### respond_to_rapid_attack

False-positive traps:

- opponent advanced a rook pawn quickly;
- opening resembles a known rapid-attack family;
- candidate directly responds to the previous move;
- engine prefers the response by a large score margin.

None of these alone proves an independently verified `rapid attack` event. Generic direct-response wording remains allowed; specialized rapid-attack wording remains blocked.

### sabai

False-positive traps:

- an exchange occurs;
- rook/bishop mobility increases;
- a major piece moves into open space;
- material returns to equality after recapture;
- position is Shikenbisha.

Build19-2 now preserves exchange/recapture events even when net material equalizes. This closes an observation gap but does not establish sabai. The 80 Build18 adversarial SHIKENBISHA_TO_SABAI controls remain non-promotion authority.

### trade_to_transform

False-positive traps:

- capture changes the board;
- promotion changes piece type;
- relation/mobility changes after exchange;
- counterfactual branch has a different board shape.

These are effects. Purpose wording such as `exchange to transform the position` remains prohibited until a role/position transformation predicate and positive semantic authority exist.

### multi_threat

False-positive traps:

- one move attacks two pieces;
- PV contains two later attacks;
- engine reply addresses one observed threat;
- multiple squares change control.

A single PV is not an exhaustive legal-response tree. Build19-2 explicitly treats PV replies as observed rather than forced. Therefore reply-independence and one-response non-neutralizability are not proven.

### tempo_management

False-positive traps:

- candidate reaches an effect one ply earlier;
- quiet move precedes an attack;
- development order differs;
- one branch is shorter;
- score is better after a timing change.

None proves timing dependence or deliberate tempo-management purpose. Matched move-order alternatives with a verified timing-dependent consequence are still required.

## Cross-cutting blockers

The following must never manufacture concept promotion:

- score gap alone;
- HIGH ComparisonConfidence on a different grounded claim;
- stable PV existence;
- sequence length;
- branch identity (ACTUAL/COUNTERFACTUAL);
- opening family;
- Shikenbisha label;
- capture/promotion/mobility fact alone;
- observed opponent PV reply treated as forced.

## Audit result before CI

No safe promotion is supported by the current semantic authority. Candidate decision: all five concepts remain HOLD and no production concept detector/output is added.
