# Build19-VE1-B — BookFile Alignment Requirement

Date: 2026-10-10
Status: **REQUIRED / NOT IMPLEMENTED**

## Finding

The VE1-A physical-device transcript showed the production app did not explicitly set `BookFile=no_book`. The engine therefore attempted its default `book/standard_book.db` and emitted a file-read warning. Verification harness paths explicitly disable the opening book.

This did not invalidate VE1-A because no book was loaded and both pinned known-answer probes matched their unchanged references. It is nevertheless a deterministic-runtime risk for future coaching analysis.

## VE1-B requirement

All coaching-analysis engine sessions must explicitly send:

`setoption name BookFile value no_book`

before `isready`.

The setting must be visible in raw diagnostics and consistent across production app, candidate comparison, regression harness, Simulator and physical-device evidence paths.

A regression fixture must demonstrate that the presence of a `standard_book.db` file cannot alter an analysis result while `BookFile=no_book` is active.

Formal acceptance is defined by B1 in `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`.
