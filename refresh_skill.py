#!/usr/bin/env python3
"""Refresh the bundled omni-video skill snapshots from the repo-root sources.

The repo root is the authoritative skill bundle (SKILL.md, mcp/, references/).
Regenerates:
  mcp/server.py                        from  server.py
  mcp/requirements.txt                 from  requirements.txt
  .claude/skills/omni-video/           assembled from SKILL.md + mcp/ + references/

SKILL.md, mcp/project-setup.sh, and references/*.md are hand-maintained sources
and copied as-is. The plugin copy in skills/ is synced by `make skill`.
"""

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SKILL = ROOT / ".claude" / "skills" / "omni-video"


def main() -> int:
    if not (ROOT / "SKILL.md").exists():
        print(
            f"error: {ROOT}/SKILL.md not found — run from the repo root",
            file=sys.stderr,
        )
        return 1

    # mcp/ snapshot of the authoritative root copies
    shutil.copyfile(ROOT / "server.py", ROOT / "mcp" / "server.py")
    print("copied server.py -> mcp/server.py")
    shutil.copyfile(ROOT / "requirements.txt", ROOT / "mcp" / "requirements.txt")
    print("copied requirements.txt -> mcp/requirements.txt")

    # assemble the installed skill copy
    if SKILL.exists():
        shutil.rmtree(SKILL)
    (SKILL / "mcp").mkdir(parents=True)
    (SKILL / "references").mkdir()
    shutil.copyfile(ROOT / "SKILL.md", SKILL / "SKILL.md")
    shutil.copyfile(ROOT / "mcp" / "server.py", SKILL / "mcp" / "server.py")
    shutil.copyfile(
        ROOT / "mcp" / "requirements.txt", SKILL / "mcp" / "requirements.txt"
    )
    shutil.copy(
        ROOT / "mcp" / "project-setup.sh", SKILL / "mcp" / "project-setup.sh"
    )  # copy() preserves +x
    for src in sorted((ROOT / "references").glob("*.md")):
        shutil.copyfile(src, SKILL / "references" / src.name)
    print(f"assembled {SKILL.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
