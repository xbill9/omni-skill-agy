---
name: omni-video
description: Generate and edit videos with Google's gemini-omni-flash-preview (Omni Flash) via the stateful Interactions API. Use when the user asks to generate a video, edit or iterate on a video, animate a still image, interpolate between keyframes, generate video with subject reference images, edit an existing local video, upload a video to YouTube, or set up/debug the Omni video MCP agent. Triggers include "generate a video", "animate this image", "omni flash", "omni-video", "video interpolation", "interaction id", "upload to YouTube".
---

# Omni Flash Video Generation

Generate and iteratively edit videos with `gemini-omni-flash-preview` — Google's
Omni Flash video model with stateful multi-turn editing via the Interactions
API. Two ways to act:

1. **Preferred — MCP agent tools.** If the `omni-video-agent` MCP server is
   connected in this session, use its tools (catalog below). They wrap the
   Interactions API calls with input encoding, File API upload/polling, and
   local video saving.
2. **Fallback — direct SDK.** If the MCP server is not connected, either offer
   to register the bundled server (see "Registering the MCP server") or call the
   Interactions API directly with the `google-genai` Python SDK using the
   examples in `references/gemini-interactions-api.md`.

## Bundled files

- `mcp/server.py` — the FastMCP Omni Flash video agent (snapshot of the
  repo-root `server.py`; the live copy at the repo root is authoritative if the
  two differ).
- `mcp/requirements.txt` — Python dependencies (`google-genai`, `mcp`). The
  `upload_to_youtube` tool additionally needs `google-api-python-client`,
  `google-auth-oauthlib`, and `google-auth-httplib2` (it reports the exact
  `pip install` command when they are missing).
- `mcp/project-setup.sh` — one-command installer: copies this skill into a
  target project and registers the MCP server (see "Registering the MCP
  server").
- `references/gemini-interactions-api.md` — the Interactions API developer
  guide for video: stateful vs. stateless architecture, parameter cheat sheet,
  Python SDK examples, delivery modes. Read it when working without the MCP
  tools, composing raw SDK calls, or answering API questions.

## Registering the MCP server

Easiest path — run the bundled installer (idempotent; installs this skill into
the target project and writes the `omni-video-agent` entry into the project's
`.mcp.json`, using the system `python3` — it warns if the pip deps below are
missing but never creates a venv):

```bash
mcp/project-setup.sh /path/to/project                    # one project
mcp/project-setup.sh --global                            # all projects (user scope)
# from the skill repo root: make init TARGET=/path/to/project ARGS='--model <name>'
```

Run `mcp/project-setup.sh --help` for all options (`--model`, `--server-name`,
`--skip-deps`). Then restart Antigravity CLI in the target project and approve the
server when prompted; `/mcp` should list `omni-video-agent`.

Manual alternative:

```bash
antigravity mcp add omni-video-agent \
  --env GEMINI_API_KEY=<key> \
  --env GEMINI_OMNI_MODEL=gemini-omni-flash-preview \
  -- python .gemini/skills/omni-video/mcp/server.py
```

Plugin alternative — install from the marketplace (auto-registers the server
via the plugin manifest; the pip deps and API key are still required, and the
server reads the key from the environment):

```
/plugin marketplace add xbill9/omni-skill-agy
/plugin install omni-video@omni-skill-agy
```

Requires: `pip install -r mcp/requirements.txt` and a Gemini API key. The
server reads config from env vars: `GEMINI_API_KEY` (or `GOOGLE_API_KEY`
fallback) and `GEMINI_OMNI_MODEL` (default `gemini-omni-flash-preview`). The
key must be set **before the server starts** — the Gemini client is created at
startup, so a missing key means the server process fails to launch, not just a
tool error. The repo-root `set_env.sh` helper reads or prompts for the key,
persists it to `~/gemini.key`, writes `.env`, and patches an existing
`.mcp.json` entry — the installer reuses `~/gemini.key` automatically when
present.

## Standard workflow

1. **Orient.** `get_help` returns the tool catalog, delivery-mode guidance, and
   cinematic prompting tips. If tools fail with auth errors (or the server
   won't start), have the user run `set_env.sh` (or export `GEMINI_API_KEY`)
   and restart the server.
2. **Generate.** `generate_video(prompt, aspect_ratio, delivery)` creates a
   video, saves it locally as an `.mp4`, and returns the saved path plus an
   **interaction ID**. Every call sets `store=True`, so the visual context
   persists on Google's servers for follow-up edits.
3. **Iterate statefully.** `edit_video(previous_interaction_id, edit_prompt)`
   applies incremental changes while preserving scene, character, and style
   continuity. Each edit returns a **new** interaction ID — always chain the
   most recent one into the next edit, not the original.
4. **Start from images or existing video when asked.**
   - `animate_image(image_path, motion_prompt)` — bring a still image to life.
   - `interpolate_images(start_image_path, end_image_path, prompt)` — a
     transition video between two keyframes.
   - `generate_with_subjects(subject_image_paths, prompt)` — a video featuring
     the people/objects in the reference images.
   - `edit_user_video(video_path, edit_prompt)` — uploads a local video via the
     Gemini File API (polls until processed, up to 5 minutes) and restyles or
     edits it.
   All of these also return interaction IDs, so subsequent refinements should
   switch to `edit_video`.
5. **Deliver.** Outputs land in the server's working directory as
   `<prefix>_<unix-timestamp>.mp4` (`gen_`, `edit_`, `animated_`,
   `interpolation_`, `subject_`, or `user_edit_` prefix). Report the absolute
   saved path back to the user.
6. **Publish (optional).** `upload_to_youtube(video_path, title, description,
   category_id, privacy_status)` uploads a saved video via the YouTube Data API
   v3. It needs one-time OAuth setup (`client_secrets.json` in the server's
   working directory; a browser window opens on first run and the token is
   cached in `token.pickle`) — the tool returns step-by-step instructions when
   credentials are missing. Default privacy is `private`; ask before uploading
   `public`.

## MCP tool catalog (by task)

**Generation:** `generate_video` (text → video), `generate_with_subjects`
(reference images + prompt → video)

**Image-driven:** `animate_image` (still image + motion prompt),
`interpolate_images` (two keyframes + transition prompt)

**Editing:** `edit_video` (stateful multi-turn edit by interaction ID),
`edit_user_video` (upload a local video file via the File API and edit it)

**Publishing:** `upload_to_youtube` (YouTube Data API v3; OAuth on first run)

**Diagnostics:** `get_help` (tool reference, delivery modes, prompting guide)

## Parameter constraints

- **Aspect ratios:** `16:9` (landscape, default) or `9:16` (portrait) — only on
  `generate_video`; other values silently fall back to the model default.
  Stateful edits inherit the previous turn's ratio.
- **Delivery modes (every video tool):** `inline` (default — base64 in the
  response; fine for small clips under ~4 MB) or `uri` (the video lands on the
  Google File API and the server polls until `ACTIVE`, then downloads —
  recommended for longer/larger clips to avoid payload-size failures).
- **Image inputs:** png/jpg/jpeg/webp local paths (mime type inferred from the
  extension; anything else is sent as png).

## Best practices & cautions

- **Prompt cinematically.** Describe scene layout, subject action, camera
  motion (pan, tracking shot, slow zoom), lighting/mood, and style
  (photorealistic, Pixar-style, macro). Specific beats vague.
- **Keep edit prompts incremental.** Describe only the change ("make it
  nighttime with rain"), not the whole scene again — the interaction context
  already holds the rest.
- **Chain the latest interaction ID.** Editing from a stale ID silently forks
  the session from an older state.
- **Prefer `delivery='uri'` for anything long or high-motion** — inline base64
  responses can hit payload limits on clips over ~4 MB.
- **Tool errors return as text.** Failures come back as `🔴 ...` (or `❌ ...`
  for YouTube) strings rather than protocol errors — check for them before
  reporting success.
- **Video generation is slow and billable.** Calls block until the video is
  ready (plus up to 5 minutes of File API polling in `uri` mode) — warn the
  user, batch related edits into one well-specified prompt, and confirm before
  large batches.
- **Never commit secrets.** `.env`, `~/gemini.key`, `.mcp.json` (which may
  carry injected keys), `client_secrets.json`, and `token.pickle` are
  gitignored here — keep it that way in target projects.
