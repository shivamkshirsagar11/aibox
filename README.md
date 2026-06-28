# vm-ai-setup

Run a state-of-the-art AI model on your Oracle Cloud VM and use it from your local machine — with zero brain usage.

One config file. A few `make` commands. Done.

---

## What you get

- **Ollama** running on your VM with a best-in-class model (default: `qwen2.5-coder:7b`)
- **Open WebUI** — a ChatGPT-like browser interface at `http://your-vm-ip:3000`
- **SSH tunnel** to use Ollama locally at `http://localhost:11434` — works with VS Code, Python, any OpenAI-compatible tool

---

## Requirements

| Where | What |
|-------|------|
| Oracle VM | Ubuntu 22.04+, 2+ OCPUs, 12GB+ RAM |
| Local machine | `make`, `ssh`, `git` |

---

## Setup (5 minutes)

### Step 1 — Clone the repo (on your VM)

```bash
git clone https://github.com/YOUR_USERNAME/vm-ai-setup.git
cd vm-ai-setup
```

### Step 2 — Edit config

```bash
nano config.env
```

Only two things you need to change:

```env
MODEL=qwen2.5-coder:7b   # or llama3.1:8b, mistral:7b, deepseek-r1:7b
VM_IP=YOUR_VM_IP_HERE    # your Oracle VM's public IP
```

### Step 3 — Install

```bash
make install
```

That's it. Ollama is installed, the model is downloaded, and Open WebUI is running.

---

## Open Oracle Cloud firewall ports ⚠️

This is the one manual step — Oracle has its own firewall separate from the OS.

1. Go to **Oracle Cloud Console → Networking → Virtual Cloud Networks**
2. Click your VCN → **Security Lists** → **Default Security List**
3. Click **Add Ingress Rules** and add:

| Stateless | Source CIDR | Protocol | Port |
|-----------|-------------|----------|------|
| No | 0.0.0.0/0 | TCP | 11434 |
| No | 0.0.0.0/0 | TCP | 3000 |

> If you skip this step, nothing will be reachable from outside.

---

## Use from your local machine

### Option A — SSH Tunnel (recommended, most secure)

Clone the repo on your local machine too, set `VM_IP` in `config.env`, then:

```bash
make tunnel
```

Ollama is now at `http://localhost:11434` on your local machine. Keep this terminal open.

### Option B — Direct access via public IP

Hit `http://your-vm-ip:11434` directly (after opening Oracle firewall ports above).

---

## Commands

```bash
make install    # Install everything on the VM
make status     # Check what's running
make pull       # Re-pull or update your model
make chat       # Quick terminal chat session
make models     # List downloaded models
make webui      # (Re)start Open WebUI
make tunnel     # SSH tunnel (run on local machine)
```

---

## Use in VS Code (free Copilot alternative)

1. Install the [Continue](https://marketplace.visualstudio.com/items?itemName=Continue.continue) extension
2. Open `~/.continue/config.json` and add:

```json
{
  "models": [
    {
      "title": "My VM",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b",
      "apiBase": "http://localhost:11434"
    }
  ]
}
```

3. Run `make tunnel` to keep the connection open
4. Use `Ctrl+I` in VS Code for inline AI assistance

---

## Use in Python / Node.js

Ollama is OpenAI-API compatible — just swap the base URL:

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:11434/v1", api_key="ollama")

response = client.chat.completions.create(
    model="qwen2.5-coder:7b",
    messages=[{"role": "user", "content": "Explain async/await in Python"}]
)
print(response.choices[0].message.content)
```

```javascript
import OpenAI from "openai";

const client = new OpenAI({ baseURL: "http://localhost:11434/v1", apiKey: "ollama" });

const res = await client.chat.completions.create({
  model: "qwen2.5-coder:7b",
  messages: [{ role: "user", content: "Write a binary search in JS" }],
});
console.log(res.choices[0].message.content);
```

---

## Model recommendations

| Model | Best for | RAM needed |
|-------|----------|------------|
| `qwen2.5-coder:7b` | Coding (default) | ~5 GB |
| `llama3.1:8b` | Chat + reasoning | ~6 GB |
| `mistral:7b` | Fast, general use | ~4 GB |
| `deepseek-r1:7b` | Step-by-step reasoning | ~5 GB |

Change model anytime in `config.env` → run `make pull` → done.

---

## Troubleshooting

**Ollama port not reachable from outside?**
→ Did you add the Ingress Rule in Oracle Cloud Console? That's the most common issue.

**`make tunnel` hangs?**
→ Make sure your SSH key is set up: `ssh ubuntu@your-vm-ip` should work without a password.

**Model download is slow?**
→ Normal — 7B models are 4–5 GB. It only downloads once.

**Out of memory?**
→ Stick to 7B or smaller models. Don't run multiple models at once.
