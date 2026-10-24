"""Flatten AXe describe-ui JSON into readable lines: type | label | value | frame."""
import json, sys
data = json.load(open(sys.argv[1]))
def walk(n, d=0):
    if isinstance(n, list):
        for c in n: walk(c, d)
    elif isinstance(n, dict):
        f = n.get("frame") or {}
        label = n.get("AXLabel") or n.get("label") or ""
        val = n.get("AXValue") or ""
        typ = n.get("type") or n.get("role") or ""
        if label or val:
            print(f'{"  "*d}{typ} | {label} | {val} | {f.get("x",0):.0f},{f.get("y",0):.0f} {f.get("width",0):.0f}x{f.get("height",0):.0f}')
        for k, v in n.items():
            if isinstance(v, (list, dict)) and k != "frame": walk(v, d+1)
walk(data)
