"""Print every label/value in AXe describe-ui JSON (stdin), one per line."""
import json, sys
def walk(n):
    if isinstance(n, list):
        for c in n: yield from walk(c)
    elif isinstance(n, dict):
        for k in ("AXLabel", "label", "AXValue", "title"):
            v = n.get(k)
            if v: yield str(v)
        for v in n.values():
            if isinstance(v, (list, dict)): yield from walk(v)
seen = set()
for t in walk(json.load(sys.stdin)):
    if t not in seen:
        seen.add(t); print(t)
