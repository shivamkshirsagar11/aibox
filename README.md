# aibox

Run a state-of-the-art AI model on your Oracle Cloud VM and use it from your local machine — with zero brain usage.

One config file. A few `make` commands. Done.

---

## What you get

- **Ollama** running on your VM with a best-in-class coding + chat model
- **Open WebUI** — a ChatGPT-like browser interface at `http://your-vm-ip:3000`
- **SSH tunnel** — use Ollama from your local machine at `http://localhost:11434`
- Works with **VS Code**, **Python**, **Node.js**, anything OpenAI-compatible

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

The only things you need to set:

```env
MODEL=qwen2.5-coder:7b    # see model recommendations below
VM_IP=YOUR_VM_IP_HERE     # your Oracle VM's public IP
SSH_KEY=~/.ssh/id_rsa     # path to your SSH private key
```

### Step 3 — Install

```bash
make install
```

That's it. Ollama is installed, model is downloaded, WebUI is running.

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
make chat           # Quick terminal chat with your model
make models         # List all downloaded models
make update-model   # Pull latest version of your current model
make switch-model   # After changing MODEL in config.env, pull the new one
```

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
      "model": "qwen2.5-coder:7b",
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
    model="qwen2.5-coder:7b",
    messages=[{"role": "user", "content": "Explain async/await in Python"}]
)
print(response.choices[0].message.content)
```

## Use in Node.js

```javascript
import OpenAI from "openai";

const client = new OpenAI({ baseURL: "http://localhost:11434/v1", apiKey: "ollama" });

const res = await client.chat.completions.create({
  model: "qwen2.5-coder:7b",
  messages: [{ role: "user", content: "Write a binary search in JS" }],
});
console.log(res.choices[0].message.content);
```

## Use via curl (quick test)

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "Write a Python hello world",
  "stream": false
}'
```

---

## Model recommendations

| Model | Best for | RAM needed |
|-------|----------|------------|
| `qwen2.5-coder:7b` | Coding — default, highly recommended | ~5 GB |
| `llama3.1:8b` | Chat + general reasoning | ~6 GB |
| `mistral:7b` | Fast, lightweight, great all-rounder | ~4 GB |
| `deepseek-r1:7b` | Step-by-step problem solving | ~5 GB |
| `nomic-embed-text` | Embeddings for RAG / semantic search | ~1 GB |

> Stick to 7B or smaller models on a 12GB RAM VM. Don't run two models at once.

### Switching models

```bash
# 1. Edit config.env
nano config.env   # change MODEL=llama3.1:8b

# 2. Pull it
make switch-model

# 3. Try it
make chat
```

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