# 🎬 Omni Flash Video Agent

[![Model: gemini-omni-flash-preview](https://img.shields.io/badge/Model-gemini--omni--flash--preview-orange.svg)](#)
[![API: Interactions API](https://img.shields.io/badge/API-Interactions%20API-blue.svg)](GEMINI.md)
[![Protocol: FastMCP](https://img.shields.io/badge/Protocol-FastMCP-green.svg)](#)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-lightgrey.svg)](LICENSE)

This repository contains a Model Context Protocol (MCP) server for interacting with **gemini-omni-flash-preview**, Google's Omni Flash video model for fast, high-fidelity video generation and editing.

Unlike traditional stateless video models, `gemini-omni-flash-preview` supports the stateful **Interactions API**, allowing AI agents and developers to iteratively edit, refine, and transform videos using natural language within a single context session — plus animate still images, interpolate between keyframes, generate with subject reference images, restyle your own video files, and publish results straight to YouTube.

---

## ✨ Features

- 🎥 **Text-to-Video**: Generate landscape (`16:9`) or portrait (`9:16`) clips from a plain prompt.
- 🔄 **Stateful Multi-Turn Edits**: Maintain scene and contextual continuity across multiple edits using interaction IDs.
- 🖼️ **Image Animation & Interpolation**: Bring a still image to life with a motion prompt, or build a transition video between two keyframes.
- 🧑‍🤝‍🧑 **Subject Reference Generation**: Feed in reference images of people or objects and direct them in a new scene.
- ✂️ **Edit Your Own Videos**: Upload a local video via the Gemini File API and restyle it ("Make it a Pixar animation style").
- 📦 **Inline & URI Delivery**: Small clips return inline as base64; larger clips are delivered through the Google File API (`delivery='uri'`) to avoid payload limits.
- ▶️ **YouTube Upload**: Publish a finished video with the YouTube Data API v3 (one-time OAuth setup).

---

## ⚙️ Environment Configuration

The MCP server checks the following environment variables on startup:

| Variable | Type | Description | Default |
| :--- | :--- | :--- | :--- |
| `GEMINI_API_KEY` | `str` | Primary API Key used to authenticate with the Gemini API. | *Required (or fallback)* |
| `GOOGLE_API_KEY` | `str` | Fallback API Key used if `GEMINI_API_KEY` is not defined. | *Optional* |
| `GEMINI_OMNI_MODEL` | `str` | Overrides the default model used for interactions. | `"gemini-omni-flash-preview"` |

> [!IMPORTANT]
> The Gemini client is created when the server starts, so the key must be in the environment **before** launch — a missing key stops the server from starting at all. Generated videos are saved as `.mp4` files in the directory the server runs from (your project directory when registered via `.mcp.json`).

---

## 🚀 Getting Started

### 1. Prerequisites

Ensure you have Python 3.10+ installed, then clone the repo and install the required dependencies using the [Makefile](Makefile) or pip:

```bash
git clone https://github.com/xbill9/omni-skill-agy.git
cd omni-skill-agy
make install
# or
pip install -r requirements.txt
```

The optional `upload_to_youtube` tool needs three extra packages (the tool prints this command itself when they are missing):

```bash
pip install google-api-python-client google-auth-oauthlib google-auth-httplib2
```

### 2. Configure Environment

You can configure your credentials interactively or reuse an existing key file using the helper script:

```bash
# Set up environment and export credentials
source set_env.sh
```

> [!NOTE]
> The `set_env.sh` script automatically reads your key from `~/gemini.key` if it exists. If not, it prompts you for the key, stores it in `~/gemini.key` for persistence across sessions, and exports both `GEMINI_API_KEY` and `GOOGLE_API_KEY` (fallback).

### 3. One-Command Bootstrap (Claude Code)

To use the agent from Claude Code in this repo, `./init.sh` does the full local setup in one pass — installs the Python dependencies, registers the `omni-video-agent` MCP server in this repo's `.mcp.json` (pointing at the repo-root [server.py](server.py)), and runs `set_env.sh` for the API key:

```bash
./init.sh        # or: source init.sh   (also exports the key into your shell)
```

Then restart Claude Code in the repo and approve the server; `/mcp` should list `omni-video-agent`.

---

## 🤖 MCP Server Integration

The FastMCP server defined in [server.py](server.py) exposes the full capabilities of `gemini-omni-flash-preview` directly to your AI agents or assistants as tools.

### Run the Server

You can run the server locally or in development mode using:

```bash
make run
# or run with MCP dev tools
mcp dev server.py
```

### 🛠️ Exposed Tools

Every video tool takes a `delivery` argument: `'inline'` (default — base64 in the response, fine for clips under ~4 MB) or `'uri'` (Google File API delivery, recommended for larger clips; the server polls until the file is `ACTIVE`, then downloads it). All results are saved locally as `<prefix>_<unix-timestamp>.mp4` and the tool reports the absolute path plus the **interaction ID** for follow-up stateful edits.

#### 1. `generate_video`
Generates an initial video from a text prompt.

* **Arguments**:
  - `prompt` (`str`): The text description of the video.
  - `aspect_ratio` (`str`): `16:9` (landscape) or `9:16` (portrait) (Default: `"16:9"`).
  - `delivery` (`str`): `inline` or `uri` (Default: `"inline"`).
* **Usage Example**:
  ```python
  generate_video(prompt="A tracking shot of a red fox running through fresh snow at golden hour", aspect_ratio="16:9", delivery="uri")
  ```

#### 2. `edit_video`
Iteratively refines a previously generated video while preserving scene and contextual continuity.

* **Arguments**:
  - `previous_interaction_id` (`str`): The unique ID returned from the previous generation or edit.
  - `edit_prompt` (`str`): Natural language description of what to change.
  - `delivery` (`str`): `inline` or `uri`.
* **Usage Example**:
  ```python
  edit_video(previous_interaction_id="int_abc123xyz", edit_prompt="make it nighttime with heavy snowfall", delivery="uri")
  ```

#### 3. `animate_image`
Animates a static local image using a motion description.

* **Arguments**:
  - `image_path` (`str`): Path to the local image file (png/jpg/webp).
  - `motion_prompt` (`str`): Instructions on how the image should animate.
  - `delivery` (`str`): `inline` or `uri`.

#### 4. `interpolate_images`
Creates a transition video between two local keyframe images.

* **Arguments**:
  - `start_image_path` (`str`) / `end_image_path` (`str`): The two keyframes.
  - `prompt` (`str`): Instruction detailing the transition (e.g. "A smooth timelapse from sunrise to sunset").
  - `delivery` (`str`): `inline` or `uri`.

#### 5. `generate_with_subjects`
Generates a video incorporating specific subjects provided as reference images.

* **Arguments**:
  - `subject_image_paths` (`list[str]`): Local paths to subject reference images.
  - `prompt` (`str`): Description of the scene and subject actions.
  - `delivery` (`str`): `inline` or `uri`.

#### 6. `edit_user_video`
Uploads a local video via the Gemini File API (polls until processed, up to 5 minutes) and edits it.

* **Arguments**:
  - `video_path` (`str`): Path to the local video file to upload and edit.
  - `edit_prompt` (`str`): What to change (e.g. "Make it a Pixar animation style").
  - `delivery` (`str`): `inline` or `uri`.

#### 7. `upload_to_youtube`
Uploads a saved video to YouTube via the YouTube Data API v3. Requires a one-time OAuth setup: place an OAuth Desktop-App `client_secrets.json` in the server's working directory; the first run opens a browser to authenticate and caches the token in `token.pickle`. The tool returns full setup instructions when credentials are missing.

* **Arguments**:
  - `video_path` (`str`): Path to the local video file.
  - `title` (`str`) / `description` (`str`): Video metadata.
  - `category_id` (`str`): YouTube category ID (Default: `"22"`, People & Blogs).
  - `privacy_status` (`str`): `private` (default), `public`, or `unlisted`.

#### 8. `get_help`
Returns the full tool reference, delivery-mode guidance, and cinematic prompting best practices. Takes no arguments.

---

## 🐳 Docker

The MCP server can be built as a Docker image
(`xbill9/omni-video-agent`) containing **only** the FastMCP server and its
open-source dependencies — no Claude Code, no API keys — so nothing needs to
be installed on the host except Docker itself.

> [!NOTE]
> This is a third-party community project, not affiliated with or endorsed by
> Anthropic or Google. You supply your own Gemini API key.

### Quick sanity check

```bash
docker run --rm -i -e GEMINI_API_KEY=dummy xbill9/omni-video-agent
# The server is now waiting for MCP JSON-RPC on stdin (Ctrl-C to exit).
```

### Use it from Claude Code

The server saves videos to its working directory and reads local files for the
image/video-input tools, so the container must see your project directory **at
the same absolute path** as the host — otherwise the tools report container
paths that don't exist on your machine. Mount it with `-v "$PWD:$PWD" -w "$PWD"`:

```bash
claude mcp add omni-video-agent --env GEMINI_API_KEY="$(cat ~/gemini.key)" -- \
  docker run --rm -i -e GEMINI_API_KEY -v "$PWD:$PWD" -w "$PWD" xbill9/omni-video-agent
```

The bare `-e GEMINI_API_KEY` (no value) forwards the variable from the `env`
block into the container without ever putting the key in the argument list.
Add `-e GEMINI_OMNI_MODEL` the same way to override the model. Restart Claude
Code and approve the server; `/mcp` should list `omni-video-agent`. (The
`upload_to_youtube` OAuth browser flow is not usable inside the container —
run that tool from a host install instead.)

### Build and publish (maintainers)

```bash
make docker-build   # xbill9/omni-video-agent:0.1.0 + :latest from server.py + requirements.txt
make docker-push    # build + push both tags (requires docker login)
```

`.dockerignore` whitelists only `server.py` and `requirements.txt`, so
key-carrying files (`.env`, `.mcp.json`, `client_secrets.json`, `token.pickle`)
can never enter the build context.

---

## 🛠️ Development & Commands

Use the [Makefile](Makefile) to streamline common workflows:

| Command | Description |
| :--- | :--- |
| `make install` | Installs Python requirements. |
| `make run` | Starts the FastMCP server. |
| `make test` | Runs the agent unit tests (mocked API). |
| `make lint` | Style and formatting checks (`ruff`) plus `bash -n` on the shell scripts. |
| `make clean` | Cleans up local Python cache files. |
| `make skill` | Refreshes all skill snapshots (`mcp/`, `.claude/skills/`, plugin copy in `skills/`) from the root sources. |
| `make skill-install` | Refreshes + copies the skill to `~/.claude/skills` (all projects). |
| `make skill-package` | Refreshes + rebuilds `dist/omni-video-skill.zip`. |
| `make init` | Refreshes + installs the Claude skill into a target project and registers the MCP server (`TARGET=/path ARGS='...'`). |
| `make docker-build` | Builds the `xbill9/omni-video-agent` Docker image (version + `latest` tags). |
| `make docker-push` | Builds + pushes both image tags to Docker Hub. |

---

## 🧩 Claude Skill

This repository is also packaged as a Claude Code skill named **`omni-video`**:

- [SKILL.md](SKILL.md) — the skill manifest: workflow, MCP tool catalog, parameter constraints, and best practices.
- `mcp/` — the bundled FastMCP server snapshot, its requirements, and `project-setup.sh` (the one-command installer).
- `references/` — the Interactions API developer guide bundled with the skill.

Install into a project (copies the skill into `<project>/.claude/skills/omni-video/` and registers the `omni-video-agent` server in the project's `.mcp.json`):

```bash
make init TARGET=/path/to/project           # one project
make init ARGS='--global'                   # all projects (user scope)
mcp/project-setup.sh --help                 # all options
```

The installer reuses `~/gemini.key` (written by `set_env.sh`) when present. Restart Claude Code in the target project afterwards; `/mcp` should list `omni-video-agent`.

> [!NOTE]
> `mcp/server.py` is a snapshot of the repo-root [server.py](server.py); the root copy is authoritative if the two differ. Run `make skill` after editing the sources to refresh every snapshot (`mcp/`, `.claude/skills/omni-video/`, and the plugin copy in `skills/`) — never edit a snapshot directly.

### Plugin marketplace

The repo is also packaged as a Claude Code plugin (`.claude-plugin/plugin.json` + `marketplace.json`), which installs the skill **and** auto-registers the `omni-video-agent` MCP server:

```
/plugin marketplace add xbill9/omni-skill-agy
/plugin install omni-video@omni-skill-agy
```

The plugin manifest carries no API key — the server reads `GEMINI_API_KEY` (or `GOOGLE_API_KEY`) from the environment, so run `source set_env.sh` first. Validate manifest changes with `claude plugin validate .`; a standalone zip of the skill is kept at `dist/omni-video-skill.zip` (rebuild with `make skill-package`).

---

## 📚 Documentation

- [GEMINI.md](GEMINI.md) - Complete Interactions API developer guide for video: Python SDK walkthrough and delivery modes.
- [SKILL.md](SKILL.md) - Claude skill manifest for the `omni-video` skill.
- [CLAUDE.md](CLAUDE.md) - Contributor guide for Claude Code: repository layout, the snapshot sync model, and coding standards.
- [references/gemini-interactions-api.md](references/gemini-interactions-api.md) - The Interactions API guide bundled with the skill.
- [LICENSE](LICENSE) - Apache-2.0.
