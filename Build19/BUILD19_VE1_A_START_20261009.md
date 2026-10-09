# Build19-VE1-A — App Engine Configuration / Runtime Verification

Start date: 2026-10-09

Base authority: Build19-VE1-Q closure commit `14e583e57e70a08ce68400dcf382518096665cf0`.

Status: STARTED / NOT QUALIFIED.

## Scope

1. Set the app engine to `FV_SCALE=24` before `isready`.
2. Verify the bundled Suisho5 `nn.bin` SHA-256 is exactly `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`.
3. Add the VE1-Q C1 startpos known-answer runtime diagnostic: `Threads=1`, `MultiPV=1`, `FV_SCALE=24`, `go depth 1`, expected `cp 108`, bestmove `7g7f`.
4. Run the known answer on iOS Simulator and provide an in-app path for the same diagnostic on a physical iPhone.
5. Audit Build17/18 and current runtime code for cp/score/threshold dependencies affected by the FV scale change. Do not silently rewrite semantic thresholds; classify and carry forward any required corrective work.
6. Add executable negative controls for missing/wrong FV scale and wrong NNUE identity where practical.

## Boundaries

- Do not start VE1-B corrective implementation.
- Do not promote historical 41/49/69 fixtures to Semantic Authority.
- Do not start HDS-H or Build20.
- If iPhone known-answer output differs from the VE1-Q authority, keep expected `cp 108` fixed and investigate the runtime/build difference.
