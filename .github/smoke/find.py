"""Read AXe describe-ui JSON on stdin; print the centre "x y" of the first element
whose label (or title/value) contains argv[1]. argv[2] optionally restricts type."""
import json, sys
exact = sys.argv[1].startswith("=")
needle = sys.argv[1].lstrip("=").lower()
want_type = (sys.argv[2] if len(sys.argv) > 2 else "").lower()
data = json.load(sys.stdin)

def walk(n):
    if isinstance(n, list):
        for c in n: yield from walk(c)
    elif isinstance(n, dict):
        yield n
        for v in n.values():
            if isinstance(v, (list, dict)): yield from walk(v)

for el in walk(data):
    label = " ".join(str(el.get(k) or "") for k in ("AXLabel", "label", "title", "AXValue"))
    typ = str(el.get("type") or el.get("role") or "").lower()
    f = el.get("frame") or {}
    own = str(el.get("AXLabel") or el.get("label") or "").lower()
    hit = (own == needle) if exact else (needle in label.lower())
    if hit and (not want_type or want_type in typ) and f.get("width"):
        print(f'{f["x"] + f["width"]/2:.0f} {f["y"] + f["height"]/2:.0f}')
        sys.exit(0)
sys.exit(1)
