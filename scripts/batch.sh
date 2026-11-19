#!/bin/bash
cd ~/harness-adapter-demo
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
L=$PWD/llama/llama-b12532/llama-server
start() { pkill -f llama-server; sleep 3
  if [ "$1" = adapter ]; then LO=(--lora models/opencode-lora/Qwen3.8-27B-opencode-lora-F16.gguf); A=qwen3.8-opencode; else LO=(); A=qwen3.8-base; fi
  nohup $L -m models/base/Qwen3.8-27B-UD-IQ3_XXS.gguf "${LO[@]}" --alias $A --port 8080 -c 16384 -np 1 -ngl 99 -fa on -ctk q8_0 -ctv q8_0 --jinja --reasoning off > results/logs/server-$1.log 2>&1 &
  for i in $(seq 1 100); do curl -s localhost:8080/health | grep -q ok && break; sleep 3; done; }
start adapter
for t in 01_moving_average 02_slugify 04_orders_multifile; do TIMEOUT_SECS=1500 scripts/run_task.sh adapter $t; echo "done adapter $t" >> results/logs/batch.progress; done
start base
for t in 03_leap_year 01_moving_average 02_slugify 04_orders_multifile; do TIMEOUT_SECS=1500 scripts/run_task.sh base $t; echo "done base $t" >> results/logs/batch.progress; done
echo ALLDONE >> results/logs/batch.progress
