#!/usr/bin/env bash
# Run one task with one model and record the result.
#
#   scripts/run_task.sh <base|adapter> <task>      e.g.  scripts/run_task.sh adapter 01_moving_average
#
# Needs llama-server already running in the SAME mode (scripts/serve.sh), plus opencode,
# python3 and pytest on PATH.
#
# What it does:
#   1. copies tasks/<task> to a temp dir (plus opencode.json, so OpenCode finds the provider)
#   2. runs `opencode run` with the task's PROMPT.txt
#   3. restores the original test files (so the model can't "pass" by editing the tests)
#   4. runs pytest, and appends one JSON line to results/results.jsonl
#   5. keeps the raw OpenCode event stream and the diff in results/logs/
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-}"
TASK="${2:-}"
PORT="${PORT:-8080}"
TIMEOUT_SECS="${TIMEOUT_SECS:-1800}"   # a 3-bit 27B on a 16 GB Mac is slow; be generous
PY="${PYTHON:-python3}"

case "$MODE" in
  base)    ALIAS="qwen3.8-base" ;;
  adapter) ALIAS="qwen3.8-opencode" ;;
  *) echo "usage: $0 <base|adapter> <task>" >&2; exit 2 ;;
esac
[[ -d "$ROOT/tasks/$TASK" ]] || { echo "no such task: $TASK (try: $(ls "$ROOT/tasks" | tr '\n' ' '))" >&2; exit 2; }
MODEL="local/$ALIAS"   # provider id "local" comes from opencode.json

# Make sure the server running on the port is the mode we are about to record.
# /v1/models is part of llama-server's OpenAI-compatible API.
if ! curl -fsS "http://localhost:$PORT/v1/models" | grep -q "\"$ALIAS\""; then
  echo "llama-server on :$PORT is not serving '$ALIAS'. Start it with: scripts/serve.sh $MODE" >&2
  exit 3
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
WORK="$(mktemp -d)"
LOGDIR="$ROOT/results/logs"
mkdir -p "$LOGDIR" "$ROOT/results"
LOG="$LOGDIR/${STAMP}_${MODE}_${TASK}.events.jsonl"
DIFF="$LOGDIR/${STAMP}_${MODE}_${TASK}.diff"

cp -R "$ROOT/tasks/$TASK"/. "$WORK"/
PROMPT="$(cat "$WORK/PROMPT.txt")"
rm -f "$WORK/PROMPT.txt"
cp "$ROOT/opencode.json" "$WORK/opencode.json"
cp -R "$WORK" "$WORK.orig"   # pristine copy for the diff and for restoring tests

# Optional timeout wrapper (macOS has neither by default: `brew install coreutils` gives gtimeout).
TO=(perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_SECS")
if command -v timeout >/dev/null 2>&1; then TO=(timeout "$TIMEOUT_SECS")
elif command -v gtimeout >/dev/null 2>&1; then TO=(gtimeout "$TIMEOUT_SECS"); fi

# --- OpenCode CLI flags -------------------------------------------------------------------
# Confirmed against the OpenCode docs / source (opencode.ai/docs/cli, run.ts):
#   --model provider/model, --format json (raw JSON events), --dir <path>
# NOT confirmed on a real run yet - check with `opencode run --help` on your Mac:
#   --standalone  private server per run (the adapter's model card uses it on `opencode run`;
#                 the CLI docs show it as a top-level flag, so it may need to move before `run`)
#   --auto        auto-approve permissions so a headless run doesn't stall on a prompt
#                 (listed in the docs' flag table; drop it if your version rejects it)
# ------------------------------------------------------------------------------------------
START="$("$PY" -c 'import time; print(time.time())')"
"${TO[@]}" opencode run \
  --auto \
  --format json \
  --dir "$WORK" \
  --model "$MODEL" \
  "$PROMPT" > "$LOG" 2> "$LOG.stderr"
OC_EXIT=$?
END="$("$PY" -c 'import time; print(time.time())')"

# Put the original tests back before judging.
for f in $(cd "$WORK.orig" && find . -name 'test_*.py'); do cp "$WORK.orig/$f" "$WORK/$f"; done

( cd "$WORK" && "$PY" -m pytest -q -p no:cacheprovider > "$LOGDIR/${STAMP}_${MODE}_${TASK}.pytest.txt" 2>&1 )
PT_EXIT=$?

diff -ru -x opencode.json -x __pycache__ -x .pytest_cache -x .opencode "$WORK.orig" "$WORK" > "$DIFF"

# Count tool calls in the JSON event stream.
# UNVERIFIED: assumes one {"type":"tool_use", ...} line per tool call, which is what earlier
# OpenCode versions emitted with --format json. If the schema differs this writes null.
"$PY" - "$ROOT/results/results.jsonl" "$LOG" "$MODE" "$TASK" "$MODEL" "$OC_EXIT" "$PT_EXIT" "$START" "$END" <<'PYEOF'
import json, sys, datetime
out, log, mode, task, model, oc_exit, pt_exit, start, end = sys.argv[1:]
calls, parsed = 0, 0
try:
    for line in open(log, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        parsed += 1
        if ev.get("type") == "tool_use":
            calls += 1
except OSError:
    pass
rec = {
    "time": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "mode": mode,
    "task": task,
    "model": model,
    "passed": int(pt_exit) == 0,
    "wall_seconds": round(float(end) - float(start), 1),
    "tool_calls": calls if (parsed and calls) else None,
    "opencode_exit": int(oc_exit),
    "pytest_exit": int(pt_exit),
}
with open(out, "a", encoding="utf-8") as f:
    f.write(json.dumps(rec) + "\n")
print(json.dumps(rec))
PYEOF

rm -rf "$WORK" "$WORK.orig"
exit 0
