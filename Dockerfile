# omni-video-agent — MCP stdio server for gemini-omni-flash-preview.
# Contains only the MCP server and its open-source deps (no Claude Code, no keys).
# Run with -i (stdio transport) and pass the key via the environment:
#   docker run --rm -i -e GEMINI_API_KEY xbill9/omni-video-agent
# Mount your project at the same absolute path so saved-video paths are valid
# on the host: -v "$PWD:$PWD" -w "$PWD"  (see README "Docker" section).
FROM python:3.12-slim

COPY requirements.txt /opt/omni-video/requirements.txt
RUN pip install --no-cache-dir -r /opt/omni-video/requirements.txt

COPY server.py /opt/omni-video/server.py

# Default output dir when no workdir mount is used; harmless when -w overrides it.
WORKDIR /videos
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["python", "/opt/omni-video/server.py"]
