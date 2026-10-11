from pathlib import Path

path = Path("iOS/ShogiCoachPoC/VE1BPhysicalQualificationView.swift")
text = path.read_text()
old = '''            sample.completion,
            String(sample.maxObservedNodes),
            sample.selectedNodes.map(String.init) ?? "nil",'''
new = '''            sample.completion,
            sample.selectedNodes.map(String.init) ?? "nil",'''
count = text.count(old)
if count != 1:
    raise SystemExit(f"semantic signature maxObservedNodes removal: expected 1, got {count}")
path.write_text(text.replace(old, new, 1))
print("adjusted shallow semantic signature")
