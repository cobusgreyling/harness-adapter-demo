#!/usr/bin/env python3
"""Print results/results.jsonl as a markdown table (paste it into the README)."""
import json, pathlib

path = pathlib.Path(__file__).resolve().parent.parent / "results" / "results.jsonl"
rows = [json.loads(l) for l in path.read_text().splitlines() if l.strip()] if path.exists() else []
print("| Task | Mode | Result | Time (s) | Tool calls |")
print("|---|---|---|---|---|")
for r in rows:
    print(f"| {r['task']} | {r['mode']} | {'pass' if r['passed'] else 'fail'} | "
          f"{r['wall_seconds']} | {r['tool_calls'] if r['tool_calls'] is not None else 'n/a'} |")
