#!/usr/bin/env bash
# Kill the orchestrator server and any claude subprocesses it spawned.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDFILE="$SCRIPT_DIR/.server.pid"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "Stopping server (pid $PID) and children..."
    # Kill the entire process group (server + claude subprocesses)
    kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null
  fi
  rm -f "$PIDFILE"
fi

# Safety net: kill any orphaned claude processes started by this server
pkill -f 'claude.*--output-format stream-json' 2>/dev/null && echo "Killed orphaned claude processes" || true
