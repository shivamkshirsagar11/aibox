# aibox

Run AI on your Oracle Cloud VM and use it from your local machine — with zero brain usage.

A **hybrid** setup: small **NVIDIA Nemotron** models run locally on your VM's CPU, while the *big* Nemotron models and **image generation** run on **NVIDIA's hosted GPUs** (free credits) — all behind one chat interface.

One config file. A few `make` commands. Done.

---

## What you get

- **Ollama** on your VM running small **Nemotron** models on the CPU — private, offline, always-on
- **NVIDIA hosted GPUs** for the heavy stuff your 12GB VM can't do:
  - **Big Nemotron models** (49B / 120B) for serious chat, coding, and reasoning
  - **Image generation** (FLUX / SDXL) via `make image`
- **Open WebUI** — a ChatGPT-like browser interface at `http://your-vm-ip:3000`, with local *and* hosted models in one dropdown
- **SSH tunnel** — use Ollama from your local machine at `http://localhost:11434`
- Works with **VS Code**, **Python**, **Node.js**, anything OpenAI-compatible

---

## How it works — local + hosted GPU

Your Oracle free-tier VM (2 OCPU / 12GB RAM, **no GPU**) is a great always-on hub, but it can't run large models or generate images at any usable speed. So aibox splits the work:

| Runs where | What | Speed |
|------------|------|-------|
| **On your VM (CPU)** | Small Nemotron models (`nemotron-mini:4b`, `nemotron-3-nano:4b`) via Ollama | Instant, private, free |
| **On NVIDIA's GPUs** | Big Nemotron (49B/120B) + image generation | Fast, free credits, one API key |

The bridge to NVIDIA is **[build.nvidia.com](https://build.nvidia.com)** — an OpenAI-compatible endpoint with free starter credits. Grab a key (`nvapi-...`), drop it in `config.env`, and the big models + image gen light up. No GPU rental, no extra servers.

---

## Requirements

| Where | What |
|-------|------|
| Oracle VM | Ubuntu 22.04+ or Amazon Linux, 2+ OCPUs, 12GB+ RAM |
| Local machine | `make`, `ssh`, `git` |

---

## Setup (5 minutes)

### Step 1 — Clone the repo on your VM

```bash
git clone https://github.com/YOUR_USERNAME/aibox.git
cd aibox
```

### Step 2 — Edit config

```bash
cp config.env.example config.env
nano config.env
```

The things you need to set:

```env
MODEL=nemotron-mini:4b       # small local model — see recommendations below
VM_IP=YOUR_VM_IP_HERE        # your Oracle VM's public IP
SSH_KEY=~/.ssh/id_rsa        # path to your SSH private key

# Optional but recommended — unlocks big models + image generation:
NVIDIA_API_KEY=nvapi-...     # free key from https://build.nvidia.com
```

> Leave `NVIDIA_API_KEY` blank and everything still works — you just get the small local models only.

### Step 3 — Install

```bash
make install
```

That's it. Ollama is installed, the local model is downloaded, WebUI is running, and (if you set an NVIDIA key) the hosted models are wired in.

---

## Open Oracle Cloud firewall ports ⚠️

Oracle has its own firewall on top of the OS — you must open ports in both.

1. Go to **Oracle Cloud Console → Networking → Virtual Cloud Networks**
2. Click your VCN → **Security Lists** → **Default Security List**
3. Click **Add Ingress Rules** and add:

| Source CIDR | Protocol | Destination Port |
|-------------|----------|-----------------|
| 0.0.0.0/0 | TCP | 11434 |
| 0.0.0.0/0 | TCP | 3000 |

> This is the #1 reason things don't work. Don't skip it.

---

## All commands

### On your VM

```bash
make install        # Install everything (Ollama + model + WebUI)
make start          # Start Ollama + WebUI
make stop           # Stop everything
make status         # See what's running
make webui          # (Re)start Open WebUI only
make chat           # Quick terminal chat with your local model
make models         # List all downloaded models
make update-model   # Pull latest version of your current model
make switch-model   # After changing MODEL in config.env, pull the new one
```

### NVIDIA hosted GPU (needs NVIDIA_API_KEY)

```bash
make ask   PROMPT="refactor this function for readability: ..."   # big Nemotron on NVIDIA GPUs
make image PROMPT="a red panda coding on a laptop, studio lighting"  # generate an image
```

Images are saved to `./images/` (and opened automatically on a desktop machine).

### On your local machine

```bash
make tunnel         # SSH tunnel → Ollama available at localhost:11434
```

---

## Use from your local machine

### Option A — SSH Tunnel (recommended)

Clone this repo on your local machine too, fill in `config.env`, then:

```bash
make tunnel
```

Ollama is now at `http://localhost:11434`. Keep this terminal open while you work.

### Option B — Direct access via public IP

Hit `http://your-vm-ip:11434` directly. Make sure Oracle firewall ports are open (see above).

---

## Use in VS Code (free GitHub Copilot alternative)

1. Install the [Continue](https://marketplace.visualstudio.com/items?itemName=Continue.continue) extension in VS Code
2. Open `~/.continue/config.json` and add:

```json
{
  "models": [
    {
      "title": "aibox",
      "provider": "ollama",
      "model": "nemotron-mini:4b",
      "apiBase": "http://localhost:11434"
    }
  ]
}
```

3. Run `make tunnel` on your local machine to keep the connection open
4. Use `Ctrl+I` for inline edits, `Ctrl+L` to open the chat sidebar

---

## Use in Python

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")

response = client.chat.completions.create(
    model="nemotron-mini:4b",
    messages=[{"role": "user", "content": "Explain async/await in Python"}]
)
print(response.choices[0].message.content)
```

**Same code, but hitting a big Nemotron model on NVIDIA's GPUs** — just swap the base URL and key:

```python
client = OpenAI(
    base_url="https://integrate.api.nvidia.com/v1",
    api_key="nvapi-...",   # your NVIDIA_API_KEY
)
response = client.chat.completions.create(
    model="nvidia/nemotron-3-ultra-550b-a55b",
    messages=[{"role": "user", "content": "Design a rate limiter"}],
)
print(response.choices[0].message.content)
```

## Use in Node.js

```javascript
import OpenAI from "openai";

const client = new OpenAI({ baseURL: "http://localhost:11434/v1", apiKey: "ollama" });

const res = await client.chat.completions.create({
  model: "nemotron-mini:4b",
  messages: [{ role: "user", content: "Write a binary search in JS" }],
});
console.log(res.choices[0].message.content);
```

## Use via curl (quick test)

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "nemotron-mini:4b",
  "prompt": "Write a Python hello world",
  "stream": false
}'
```

---

## Model recommendations

### Local — runs on the VM CPU (set as `MODEL`)

| Model | Best for | Size / RAM |
|-------|----------|------------|
| `nemotron-mini:4b` | NVIDIA Nemotron — chat, RAG, function calling. **Default.** | ~2.7 GB |
| `nemotron-3-nano:4b` | Newer Nemotron — reasoning + non-reasoning, 256K context | ~2.8 GB |
| `qwen2.5-coder:7b` | Strong coding model | ~5 GB |
| `llama3.1:8b` | General chat + reasoning | ~6 GB |
| `mistral:7b` | Fast, lightweight all-rounder | ~4 GB |

> On a 12GB VM stick to 4B models for comfortable headroom (WebUI + OS also need RAM). 7B works but is tight — don't run two models at once. The 30B Nemotron (`nemotron-3-nano:30b`, ~24GB) will **not** fit — use the hosted version instead.

### Hosted on NVIDIA's GPUs — the big ones (set as `NVIDIA_MODEL`)

These run on [build.nvidia.com](https://build.nvidia.com), not your VM, so size doesn't matter:

| Model | Params | Best for |
|-------|--------|----------|
| `nvidia/nemotron-3-ultra-550b-a55b` | 550B (55B active) | Flagship reasoning & agentic work. **Default.** |
| `nvidia/nemotron-4-340b-instruct` | 340B | Very strong instruction following |
| `nvidia/llama-3.1-nemotron-ultra-253b-v1` | 253B | Dense high-end reasoning |
| `nvidia/nemotron-3-super-120b-a12b` | 120B (12B active) | Faster, still excellent |
| `nvidia/llama-3.3-nemotron-super-49b-v1.5` | 49B | Quickest, easiest on credits |

The 550B is a Mixture-of-Experts model (only 55B params active per token), so it's far faster and cheaper on credits than a dense 550B would be — but it's still the heaviest option. Drop to the 120B or 49B if you want snappier replies. Browse the full catalog at [build.nvidia.com](https://build.nvidia.com); use any model via `make ask` or straight from the Open WebUI dropdown.

### Switching the local model

```bash
# 1. Edit config.env
nano config.env   # change MODEL=nemotron-3-nano:4b

# 2. Pull it
make switch-model

# 3. Try it
make chat
```

---

## Image generation

Your CPU-only VM can't generate images at any usable speed, so aibox offloads it to NVIDIA's GPUs. Just need `NVIDIA_API_KEY` set.

```bash
make image PROMPT="a cozy cyberpunk coffee shop, neon rain, cinematic"
```

The PNG lands in `./images/` (and opens automatically if you're on a desktop). Change the model + steps in `config.env`:

| `IMAGE_MODEL` | `IMAGE_STEPS` | Notes |
|---------------|:-------------:|-------|
| `black-forest-labs/flux.1-dev` | `50` | 12B state-of-the-art quality. **Default.** |
| `black-forest-labs/flux.1-schnell` | `4` | Distilled — fast 4-step drafts |
| `stabilityai/stable-diffusion-3.5-large` | `50` | 8B, rich artistic styles |

> `flux.1-dev` is the best quality but needs ~50 steps (a few seconds on NVIDIA's GPUs). For quick drafts, switch to `flux.1-schnell` with `IMAGE_STEPS=4`.

**Want image gen inside the chat UI too?** Open WebUI supports it via **Settings → Images**. Point it at a ComfyUI backend if you run one, or use the `make image` command for a no-fuss GPU-hosted option.

---

## Troubleshooting

**Nothing reachable from outside the VM?**
→ Open ports in Oracle Cloud Console (see above). This is the most common issue — Oracle has two separate firewalls.

**`sudo: apt-get: command not found`**
→ You're on Amazon Linux / RHEL. The install script handles this automatically — make sure you're on the latest version of this repo.

**`make tunnel` hangs or refuses connection?**
→ Check that `SSH_KEY` in `config.env` points to the right key file. Test manually: `ssh -i ~/.ssh/your-key.pem ubuntu@your-vm-ip`

**Model download is slow?**
→ Normal — 7B models are 4–5 GB. It only downloads once.

**Out of memory / model crashes?**
→ Run `make stop`, then `make start` to free up RAM. Switch to a smaller model like `mistral:7b`.

**WebUI won't start?**
→ Run `make webui` to restart it. If Docker isn't installed, run `make install` again.

**`make ask` / `make image` says the API key isn't set?**
→ Add `NVIDIA_API_KEY=nvapi-...` to `config.env`. Get a free key at [build.nvidia.com](https://build.nvidia.com).

**`make ask` / `make image` says `jq` is required?**
→ Install it: `sudo apt install jq` (Ubuntu) or `brew install jq` (macOS). `make install` does this for you on the VM.

**NVIDIA API error: 401 / out of credits?**
→ Your key is wrong or credits are exhausted. Check the key, or see your usage at [build.nvidia.com](https://build.nvidia.com).

**Hosted Nemotron models don't appear in Open WebUI?**
→ You set the key *after* starting WebUI. Re-run `make webui` (or `make install`) so the container picks it up.

**`make image` couldn't find image data in the response?**
→ Different image models return slightly different shapes. Try a different `IMAGE_MODEL` in `config.env` (e.g. `black-forest-labs/flux.1-schnell`).