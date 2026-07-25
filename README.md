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
- **Open WebUI** — a ChatGPT-like browser interface at `http://your-vm-ip:3000`. Pick a Nemotron model from the dropdown for text chat, or a **🎨 image model** to generate pictures **inline in the chat** (with download) — local, hosted, and image models all in one selector
- **Daily cleanup** that auto-deletes old generated images
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

## The chat platform — text *and* images in one UI

Open WebUI (`http://your-vm-ip:3000`) is the front end. Everything is picked from the **model dropdown** at the top of the chat:

| Pick this model | What happens |
|-----------------|--------------|
| `nvidia/nemotron-3-ultra-550b-a55b` (and other Nemotron entries) | Normal **text chat** — responses render as markdown (code blocks, tables, math) |
| `nemotron-mini:4b` / other local models | Text chat on your VM's CPU (private, offline) |
| **🎨 FLUX.1-dev** / 🎨 Qwen-Image / 🎨 SD 3.5 Large | **Image generation** — type a prompt, the image renders **inline in the chat** with a **download button**, full quality |

So it works exactly like you described: choose an image model → your prompt goes to image gen; choose Nemotron → normal chat. One interface, no mode switching.

### One-time: add the image models to the dropdown

Image gen goes through a small **Open WebUI Function** (`openwebui/nvidia_image.py`) — Open WebUI can't talk to NVIDIA's image API without it. Install it once:

```bash
make pipe          # prints the function (and copies it to your clipboard on macOS)
```

Then in the browser:
1. Open WebUI → **Admin Panel → Functions** → **+ (New Function)**
2. Paste the contents of `openwebui/nvidia_image.py`, **Save**, and toggle it **on**
3. The **🎨** image models now appear in the chat model dropdown

The API key is picked up automatically from the container (we pass `NVIDIA_API_KEY` in), so there's nothing else to configure. Images come back at full quality (1024×1024 by default, up to **1344×1344**) — click the image in chat and hit download.

### Or generate from the terminal

```bash
make image PROMPT="a cozy cyberpunk coffee shop, neon rain, cinematic"
```

Saves the file to `./images/` and opens it on a desktop. Tune `config.env`:

| Setting | Options |
|---------|---------|
| `IMAGE_MODEL` | `black-forest-labs/flux.1-dev` (best), `…/flux.1-schnell` (fast), `qwen/qwen-image` (text in images), `stabilityai/stable-diffusion-3.5-large` |
| `IMAGE_STEPS` | `50` for `flux.1-dev` (min 5); `4` for `flux.1-schnell` |
| `IMAGE_WIDTH` / `IMAGE_HEIGHT` | one of `768 832 896 960 1024 1088 1152 1216 1280 1344` |

> FLUX returns **JPEG** (NVIDIA's delivery format) — we save the exact bytes with no re-compression, so it's the max quality the API gives. There's no lossless/PNG option on the hosted endpoint.

### Housekeeping — auto-delete old images

Generated images (both `./images/` and the ones stored inside Open WebUI) are cleaned on a schedule so they don't pile up:

```bash
make cleanup           # delete images older than CLEANUP_DAYS (default 1) now
make cleanup-install   # install a daily cron (03:30) that does it automatically
make cleanup-uninstall # remove that cron
```

The cleanup only touches generated images — it never deletes your uploaded documents or chat history.

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

**`make image` fails with `steps` error?**
→ `flux.1-dev` requires `IMAGE_STEPS` ≥ 5. Only `flux.1-schnell` allows 1–4 steps.

**🎨 image models don't show in the chat dropdown?**
→ Make sure you pasted `openwebui/nvidia_image.py` into Admin → Functions **and toggled it on**. Re-check that `make webui` ran *after* `NVIDIA_API_KEY` was set (the key is passed into the container for the function to use).

**Image gen in chat says the API key is empty?**
→ The function reads `NVIDIA_API_KEY` from the container env. If it's blank, open the function's ⚙️ **Valves** in Open WebUI and paste your `nvapi-...` key there directly.

**Hitting rate limits?**
→ NVIDIA's free tier is ~40 requests/minute shared across all models. Space out heavy image batches.