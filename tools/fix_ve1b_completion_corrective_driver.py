#!/usr/bin/env python3
from pathlib import Path

p = Path('tools/apply_ve1b_completion_state_corrective.py')
s = p.read_text(encoding='utf-8')

old = '''    old = \'\'\'                      && $0.actualAnalysisSource.hasPrefix("equal-condition")\\n\'\'\'\n    new = \'\'\'                      && $0.actualAnalysisSource.hasPrefix("node-equal-condition")\\n\'\'\'\n    text = replace_once(text, old, new, "simulator diagnostic node source")\n'''
new = '''    old = '$0.actualAnalysisSource.hasPrefix("equal-condition")'\n    new = '$0.actualAnalysisSource.hasPrefix("node-equal-condition")'\n    text = replace_once(text, old, new, "simulator diagnostic node source")\n'''
if s.count(old) != 1:
    raise SystemExit(f'diagnostic driver pattern count={s.count(old)}')
s = s.replace(old, new, 1)

# The helper block was the only raw Python string containing escaped Swift keypaths.
# Make it a normal triple-quoted string so `\\.` in the driver emits Swift `\.`.
if s.count("    helpers = r'''    private static func deepCompletionContractPass(") != 1:
    raise SystemExit('helpers raw-string marker mismatch')
s = s.replace(
    "    helpers = r'''    private static func deepCompletionContractPass(",
    "    helpers = '''    private static func deepCompletionContractPass(",
    1,
)

p.write_text(s, encoding='utf-8')
print('completion corrective driver hardened')
