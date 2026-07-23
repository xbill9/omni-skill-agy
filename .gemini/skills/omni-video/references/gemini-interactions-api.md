# Gemini Interactions API — Video Guide (gemini-omni-flash-preview)

The **Interactions API** is Gemini's stateful endpoint: each call returns an
`interaction_id` representing the turn's visual context persisted server-side,
and passing `previous_interaction_id` lets the model edit the existing video
while preserving scene, character, lighting, and style continuity — no
re-prompting the full scene. This guide covers using it for video with
`gemini-omni-flash-preview` (Omni Flash) via the `google-genai` Python SDK.
Use it when composing raw SDK calls without the Omni video MCP tools, or when
answering questions about the API itself.

---

## Stateful vs. stateless

1. **Generate**: `client.interactions.create(...)` with `store=True` returns a
   video plus a unique `interaction_id`.
2. **Edit**: pass `previous_interaction_id` with an incremental edit prompt.
   The model retrieves the stored context and applies only the change.
3. **Chain**: every turn returns a **new** interaction ID — always chain the
   latest one; editing from a stale ID silently forks from an older state.

---

## Parameter cheat sheet — `client.interactions.create(...)`

| Parameter | Type | Notes |
| :--- | :--- | :--- |
| `model` | `str` | `"gemini-omni-flash-preview"`. |
| `input` | `str` \| `list` | Text prompt, or a list of parts: `{"type": "image", "data": <b64>, "mime_type": ...}`, `{"type": "document", "uri": <file-api-uri>}` (an uploaded video), and `{"type": "text", "text": ...}`. |
| `response_format` | `dict` | `{"type": "video"}`; optional `"aspect_ratio"`: `16:9` (landscape) or `9:16` (portrait) — generation only, stateful edits inherit it; optional `"delivery": "uri"` for File API delivery. |
| `previous_interaction_id` | `str` | Stateful edit of a prior turn. |
| `store` | `bool` | `True` for any turn you may edit later. |
| `background` | `bool` | `False` blocks until the video is ready. |

### Delivery modes

- **inline** (default): the response embeds the video as base64 in
  `interaction.output_video.data`. Use for short clips (< ~4 MB) — larger
  payloads can fail.
- **uri**: the output lands on the **Google File API**;
  `interaction.output_video.uri` points at it. Poll `client.files.get(...)`
  until state `ACTIVE` (fail on `FAILED`), then `client.files.download(...)`.
  Recommended for long or high-motion clips.

---

## Python SDK examples

```python
import base64
from google import genai

client = genai.Client()  # reads GEMINI_API_KEY / GOOGLE_API_KEY from the env

# 1. Text-to-video
interaction = client.interactions.create(
    model="gemini-omni-flash-preview",
    input="A tracking shot of a red fox running through fresh snow at golden hour",
    response_format={"type": "video", "aspect_ratio": "16:9"},
    background=False,
    store=True,
)
with open("fox.mp4", "wb") as f:
    f.write(base64.b64decode(interaction.output_video.data))

# 2. Stateful edit — incremental prompt, latest interaction ID
edited = client.interactions.create(
    model="gemini-omni-flash-preview",
    previous_interaction_id=interaction.id,
    input="Make it nighttime with heavy snowfall",
    response_format={"type": "video"},
    background=False,
    store=True,
)

# 3. Animate a still image (inline base64 image part + motion prompt)
with open("portrait.png", "rb") as f:
    b64_data = base64.b64encode(f.read()).decode("utf-8")

animated = client.interactions.create(
    model="gemini-omni-flash-preview",
    input=[
        {"type": "image", "data": b64_data, "mime_type": "image/png"},
        {"type": "text", "text": "The subject turns and smiles as the camera slowly zooms in"},
    ],
    response_format={"type": "video"},
    background=False,
    store=True,
)

# 4. Keyframe interpolation: two image parts + a transition prompt
# 5. Subject reference: N subject image parts + a scene prompt
#    (same shape as #3 — just add more image parts before the text part)

# 6. Edit an existing local video: upload via the File API, reference as a document
video_file = client.files.upload(file="clip.mp4")
while video_file.state == "PROCESSING":
    video_file = client.files.get(name=video_file.name)

restyled = client.interactions.create(
    model="gemini-omni-flash-preview",
    input=[
        {"type": "document", "uri": video_file.uri},
        {"type": "text", "text": "Make it a Pixar animation style"},
    ],
    response_format={"type": "video", "delivery": "uri"},
    background=False,
    store=True,
)
```

---

## Best practices

- **Prompt cinematically**: scene layout, subject action, camera motion
  (pan, tracking shot, crane shot, slow zoom), lighting/mood (golden hour,
  neon glow, moody shadows), and explicit style (photorealistic, Pixar-style,
  macro, 2D flat design).
- **Keep edit prompts incremental** — describe only the change; the stored
  context holds the rest.
- **Pick aspect ratio at generation time** — stateful edits inherit it.
- **Prefer `uri` delivery** for anything that might exceed ~4 MB inline.
- **Generations block and are billable** — batch related edits into one
  well-specified prompt when latency or cost matters.

## Links

- [Interactions API Reference](https://ai.google.dev/api/interactions-api)
- [Raw Interactions API details](https://ai.google.dev/api/interactions.md.txt)
- [Gemini Omni prompting guide](https://deepmind.google/models/gemini-omni/prompt-guide/)
