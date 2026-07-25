"""
title: NVIDIA Image Generation (FLUX / SD3.5)
author: aibox
version: 0.1.0
required_open_webui_version: 0.5.0
description: Generate images on NVIDIA's hosted GPUs (build.nvidia.com) right
    inside the chat. Each model shows up in the model dropdown; pick one, type a
    prompt, and the image renders inline with a download button (full quality).
"""

import base64
import os

import httpx
from pydantic import BaseModel, Field


# Models exposed in the chat dropdown -> their NVIDIA genai model id.
# name is what the user sees; id is the path segment on ai.api.nvidia.com.
MODELS = [
    {"id": "black-forest-labs/flux.1-dev", "name": "🎨 FLUX.1-dev (best quality)"},
    {"id": "black-forest-labs/flux.1-schnell", "name": "🎨 FLUX.1-schnell (fast)"},
    {"id": "qwen/qwen-image", "name": "🎨 Qwen-Image (best for text in images)"},
    {"id": "stabilityai/stable-diffusion-3.5-large", "name": "🎨 Stable Diffusion 3.5 Large"},
]

# Valid FLUX/Qwen sizes on NVIDIA: 768 832 896 960 1024 1088 1152 1216 1280 1344
ALLOWED_SIZES = [768, 832, 896, 960, 1024, 1088, 1152, 1216, 1280, 1344]
# SD 3.5 Large takes an aspect_ratio instead of width/height.
SD_ASPECT_RATIOS = {
    (1, 1): "1:1", (16, 9): "16:9", (21, 9): "21:9", (3, 2): "3:2",
    (2, 3): "2:3", (4, 5): "4:5", (5, 4): "5:4", (9, 16): "9:16", (9, 21): "9:21",
}


def _nearest_size(v: int) -> int:
    return min(ALLOWED_SIZES, key=lambda a: abs(a - v))


def _aspect_ratio(w: int, h: int) -> str:
    target = w / h
    return min(SD_ASPECT_RATIOS.items(), key=lambda kv: abs(kv[0][0] / kv[0][1] - target))[1]


def _build_payload(model_id: str, prompt: str, width: int, height: int,
                   steps: int, cfg_scale: float) -> dict:
    """Each NVIDIA image family has a slightly different request schema."""
    if "stable-diffusion-3.5" in model_id:
        return {"prompt": prompt, "aspect_ratio": _aspect_ratio(width, height),
                "cfg_scale": cfg_scale, "steps": steps, "seed": 0, "samples": 1}
    if "qwen" in model_id:
        return {"prompt": prompt, "width": width, "height": height,
                "num_inference_steps": steps, "cfg_scale": cfg_scale, "seed": 0}
    # FLUX (dev / schnell)
    return {"prompt": prompt, "width": width, "height": height,
            "steps": steps, "cfg_scale": cfg_scale, "seed": 0}


def _get_prompt(body: dict, metadata: dict) -> str:
    # Prefer the raw pre-RAG prompt Open WebUI exposes; fall back to messages.
    if metadata and metadata.get("user_prompt"):
        return metadata["user_prompt"]
    for m in reversed(body.get("messages", [])):
        if m.get("role") == "user":
            c = m.get("content")
            if isinstance(c, str):
                return c
            if isinstance(c, list):
                for part in c:
                    if part.get("type") == "text":
                        return part.get("text", "")
    return ""


class Pipe:
    class Valves(BaseModel):
        NVIDIA_API_KEY: str = Field(
            default_factory=lambda: os.environ.get("NVIDIA_API_KEY", ""),
            description="NVIDIA API key (nvapi-...). Auto-filled from the "
            "container's NVIDIA_API_KEY env var if set.",
        )
        API_BASE_URL: str = Field(
            default="https://ai.api.nvidia.com/v1/genai",
            description="NVIDIA genai image endpoint base URL.",
        )
        WIDTH: int = Field(default=1024, description="Image width (768-1344).")
        HEIGHT: int = Field(default=1024, description="Image height (768-1344).")
        STEPS: int = Field(default=50, description="Denoising steps (dev needs >=5).")
        CFG_SCALE: float = Field(default=3.5, description="Prompt adherence.")

    def __init__(self):
        self.valves = self.Valves()

    def pipes(self):
        return MODELS

    async def pipe(
        self,
        body: dict,
        __user__: dict = None,
        __request__=None,
        __event_emitter__=None,
        __metadata__: dict = None,
    ):
        # Resolve which image model was selected (strip Open WebUI's prefix).
        selected = body.get("model", "")
        model_id = next((m["id"] for m in MODELS if selected.endswith(m["id"])),
                        MODELS[0]["id"])

        prompt = _get_prompt(body, __metadata__)
        if not prompt.strip():
            return "Please type a prompt describing the image you want."

        # schnell allows 1-4 steps; dev / sd3.5 need >= 5.
        steps = self.valves.STEPS
        if "schnell" not in model_id:
            steps = max(steps, 5)

        width = _nearest_size(self.valves.WIDTH)
        height = _nearest_size(self.valves.HEIGHT)

        async def status(msg, done=False):
            if __event_emitter__:
                await __event_emitter__(
                    {"type": "status", "data": {"description": msg, "done": done}}
                )

        await status(f"Generating with {model_id} ({width}x{height})...")

        payload = _build_payload(model_id, prompt, width, height, steps,
                                 self.valves.CFG_SCALE)
        headers = {
            "Authorization": f"Bearer {self.valves.NVIDIA_API_KEY}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=180) as client:
                r = await client.post(
                    f"{self.valves.API_BASE_URL}/{model_id}",
                    headers=headers,
                    json=payload,
                )
                r.raise_for_status()
                data = r.json()
        except httpx.HTTPStatusError as e:
            detail = ""
            try:
                detail = e.response.json()
            except Exception:
                detail = e.response.text[:400]
            await status(f"Failed: {e}", done=True)
            return f"**Image generation failed** ({e.response.status_code}):\n\n```\n{detail}\n```"
        except Exception as e:
            await status(f"Failed: {e}", done=True)
            return f"**Image generation failed:** {e}"

        # NVIDIA models return base64 in different fields; try the known shapes.
        b64 = None
        if isinstance(data.get("artifacts"), list) and data["artifacts"]:
            b64 = data["artifacts"][0].get("base64")
        b64 = b64 or data.get("image")
        if not b64 and isinstance(data.get("data"), list) and data["data"]:
            b64 = data["data"][0].get("b64_json")
        if not b64:
            await status("No image in response", done=True)
            return f"**No image data in response.** Keys: `{list(data.keys())}`"

        # Strip a possible data-URI prefix; FLUX returns JPEG bytes.
        if b64.startswith("data:"):
            b64 = b64.split(",", 1)[-1]
        raw = base64.b64decode(b64)
        mime = "image/png" if raw[:4] == b"\x89PNG" else "image/jpeg"
        b64 = base64.b64encode(raw).decode()

        await status("Done", done=True)
        # Inline Markdown image -> renders in chat, click = viewer + download.
        return f"![{prompt}](data:{mime};base64,{b64})"
