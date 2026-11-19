# harness-adapter-demo

A small, honest test of a Hugging Face **harness adapter** on a laptop.

I run `Qwen/Qwen3.8-27B` twice on the same four bug-fixing tasks, inside the same coding harness (OpenCode):

1. the plain base model
2. the base model plus Hugging Face's OpenCode adapter, `harness-hub/Qwen3.8-27B-opencode-adapted`

Everything runs locally on a 16 GB M2 Pro MacBook, through llama.cpp, at 3-bit.

## Why this matters

For years the order was: pick a model, then wrap a harness around it. A harness adapter flips that. The adapter is a small LoRA, trained with reinforcement learning *inside* one specific harness (here, OpenCode), so the model learns how that harness works... its tools, its loop, its habits.

So you can't judge the model on its own anymore. You judge **model + harness as a pair**.

The model is rented. The harness is owned.

## What Hugging Face reports

From the [adapter's GGUF card](https://huggingface.co/harness-hub/Qwen3.8-27B-opencode-adapted-GGUF), base model vs. base + OpenCode adapter:

| Benchmark | Base | With adapter |
|---|---|---|
| SWE-bench Pro (hard 51) | 35.3% | 51.0% |
| Terminal-Bench 2.1 | 46.4% | 52.4% |

Their scores come from the **BF16** adapter served by vLLM, under the OpenCode harness, thinking off, one attempt per task.

## Read this before you quote anything from this repo

**This is a small local test. It is not a benchmark.**

- The adapter was trained and evaluated at **BF16**. I run a **3-bit** base (unsloth `UD-IQ3_XXS`) so it fits in 16 GB. The card itself says a quantized base "will move the results further", and it suggests Q8_0 as the default, with Q4_K_M as a smaller option that drifts further. 3-bit is smaller than both.
- The GGUF adapter has not been re-evaluated through llama.cpp, per the card.
- Even the harness version differs. Hugging Face trained and evaluated with OpenCode 2.2.7 (`@opencode/cli`); my MacBook run used OpenCode 1.19.3. Which itself illustrates the point: the adapter belongs to a model + harness pair, and a different harness version is already a different pair.
- I have four tasks. Three are tiny, one touches several files. One run per task per mode. That shows what happened on my machine on that day, nothing more.
- Do not compare my pass/fail table with the numbers above. Different tasks, different precision, different scale.
- Thinking is off for both models (`enable_thinking: false`), as in the adapter's training and evaluation.

## The tasks

Pure Python, standard library only. Each folder in `tasks/` has a buggy module, a pytest file that fails, and a one-line prompt (`PROMPT.txt`).

| Task | What's wrong |
|---|---|
| `01_moving_average` | off-by-one in a loop |
| `02_slugify` | regex doesn't collapse runs, result isn't stripped |
| `03_leap_year` | century rule missing |
| `04_orders_multifile` | the harder one: bugs in two files of a small `orders` package |

Reference fixes live in `solutions/`, not in the task folders, so the model can't see them. `scripts/verify_tasks.sh` checks that every task fails as shipped and passes with its reference fix.

## Setup

You need: a Mac with 16 GB or more, [llama.cpp](https://github.com/ggml-org/llama.cpp), [OpenCode](https://opencode.ai/docs/cli/), Python 3 with `pytest`, and the Hugging Face CLI (`hf`). About 11.3 GB of disk for the models.

```sh
git clone https://github.com/cobusgreyling/harness-adapter-demo ~/harness-adapter-demo
cd ~/harness-adapter-demo
chmod +x scripts/*.sh scripts/summarize.py

# 1. models (~10.9 GB base + ~0.3 GB adapter)
hf download unsloth/Qwen3.8-27B-GGUF Qwen3.8-27B-UD-IQ3_XXS.gguf --local-dir models/base
hf download harness-hub/Qwen3.8-27B-opencode-adapted-GGUF Qwen3.8-27B-opencode-lora-F16.gguf --local-dir models/opencode-lora

# 2. check the tasks themselves
scripts/verify_tasks.sh

# 3. serve the BASE model (terminal 1)
scripts/serve.sh base

# 4. run the tasks against it (terminal 2)
for t in tasks/*/; do scripts/run_task.sh base "$(basename "$t")"; done

# 5. stop the server, then serve the ADAPTER and repeat
scripts/serve.sh adapter
for t in tasks/*/; do scripts/run_task.sh adapter "$(basename "$t")"; done

# 6. table for the README
scripts/summarize.py
```

`serve.sh` runs `llama-server` on port 8080 with `-c 16384 -np 1 -ngl 99 -fa on -ctk q8_0 -ctv q8_0 --jinja --reasoning off` (and `--lora` for the adapter). `scripts/batch.sh` is the detached script I used to run the whole sweep. The two modes use different aliases, `qwen3.8-base` and `qwen3.8-opencode`, and `run_task.sh` refuses to run if the server on the port isn't the mode you asked for.

`opencode.json` points OpenCode at the local server as an OpenAI-compatible provider.

Every run appends a line to `results/results.jsonl`: mode, task, pass/fail, wall time, tool calls if they can be read from OpenCode's event stream. Raw events, the diff and the pytest output go to `results/logs/`; the committed copies are from the 19 Nov run (server logs are not committed). The original tests are copied back before pytest runs, so editing the tests can't count as a pass.

Expect it to be slow. A 3-bit 27B on 16 GB of memory generates a handful of tokens a second, and agent prompts are long.

## Results

Run on 19 Nov 2026. MacBook Pro M2 Pro, 16 GB, llama.cpp b12532, OpenCode 1.19.3, unsloth `UD-IQ3_XXS` base, F16 GGUF adapter. About 6 to 8 tokens a second, and a ~9k-token OpenCode system prompt on every run. One run per task per mode. Pytest decides pass/fail, with the original tests copied back first.

Output of `python3 scripts/summarize.py`:

| Task | Mode | Result | Time (s) | Tool calls |
|---|---|---|---|---|
| 03_leap_year | adapter | pass | 286.7 | 7 |
| 01_moving_average | adapter | pass | 291.3 | 7 |
| 02_slugify | adapter | pass | 308.5 | 5 |
| 04_orders_multifile | adapter | pass | 375.3 | 12 |
| 03_leap_year | base | pass | 284.1 | 7 |
| 01_moving_average | base | pass | 251.1 | 5 |
| 02_slugify | base | pass | 270.3 | 5 |
| 04_orders_multifile | base | pass | 588.2 | 13 |

Side by side:

| Task | Base (s / calls) | Adapter (s / calls) |
|---|---|---|
| 01_moving_average | 251.1 / 5 | 291.3 / 7 |
| 02_slugify | 270.3 / 5 | 308.5 / 5 |
| 03_leap_year | 284.1 / 7 | 286.7 / 7 |
| 04_orders_multifile | 588.2 / 13 | **375.3 / 12** |

The raw data is in `results/results.jsonl`. For every run, `results/logs/` has the diff the model made, the pytest output and OpenCode's event stream. The llama.cpp server logs are left out.

## What this shows... and what it doesn't

**What it shows**

- Both setups fixed all four bugs. Pass rate: 4/4 vs 4/4. No difference.
- On the hardest task (two bugs, spread across the `orders` package) the adapter finished in 375 s against 588 s for the base model, about 36% faster, with 12 tool calls against 13.
- On the three easy single-file tasks the base model was equal or a bit faster (about 3 to 40 s).
- A 27B model with a LoRA adapter can drive an agent harness end to end on a 16 GB laptop. Slowly.

**What it doesn't show**

- It is **not a benchmark**. n=1 per cell, four toy tasks, no repeats, so the timing gap on task 04 could be noise.
- It says nothing about the 51.0% vs 35.3% SWE-bench Pro result. Different tasks, different scale, different precision.
- The adapter was trained and evaluated at BF16 under vLLM. I ran a 3-bit base through llama.cpp, and Hugging Face has not re-evaluated the GGUF adapter. A quantized base may well move the results.
- Tasks this easy are where an adapter has the least to add.
- I only tested the OpenCode adapter inside OpenCode. I did not test it in another harness, so I can't say whether the gains carry over. HF trained it for one harness, which is the point of the whole exercise.

**The takeaway**

The adapter is trained *for* a specific harness. So you evaluate the model and the harness as one unit, not the model alone. The claim to test is not "is this model better" but "is this model, in my harness, better".

## Links

- Base model: [Qwen/Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B)
- Adapter (BF16): [harness-hub/Qwen3.8-27B-opencode-adapted](https://huggingface.co/harness-hub/Qwen3.8-27B-opencode-adapted)
- Adapter (GGUF, for llama.cpp): [harness-hub/Qwen3.8-27B-opencode-adapted-GGUF](https://huggingface.co/harness-hub/Qwen3.8-27B-opencode-adapted-GGUF)
- 3-bit base GGUF: [unsloth/Qwen3.8-27B-GGUF](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF)
- Clem Delangue's launch post: https://x.com/ClementDelangue/status/2122784279604383914

## License

Apache-2.0, see [LICENSE](LICENSE). The models have their own licenses; check their cards.

— Cobus Greyling · [www.cobusgreyling.com](https://www.cobusgreyling.com)
