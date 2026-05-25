#!/usr/bin/env bash
# AI agent wrapper with multi-tier fallback.
#
# Tier 1: Claude Code via Pro subscription (CLAUDE_CODE_OAUTH_TOKEN)
# Tier 2: OpenCode Go with task-appropriate model
#          - review mode → opencode-go/glm-5.1 (heavy reasoning)
#          - fix mode    → opencode/deepseek-v4-flash-free (free tier)
#                       → opencode-go/qwen3.6-plus (Go subscription fallback)
#                       → opencode-go/deepseek-v4-flash (last resort)
#
# Verified model slugs as of opencode v1.15.7 (2026-05-25):
#   opencode-go/glm-5.1
#   opencode/deepseek-v4-flash-free
#   opencode-go/qwen3.6-plus
#   opencode-go/deepseek-v4-flash
#
# Usage: ./ai-agent.sh "<task>" [--mode review|fix] [--max-turns N]
#
# Required env: CLAUDE_CODE_OAUTH_TOKEN, OPENCODE_API_KEY
# MUST NOT BE SET: ANTHROPIC_API_KEY (would override Pro OAuth token and incur PAYG charges)

set -euo pipefail

TASK="${1:?usage: ai-agent.sh \"<task>\" [--mode review|fix] [--max-turns N]}"
MODE="fix"
MAX_TURNS="25"

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --max-turns) MAX_TURNS="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Safety: ANTHROPIC_API_KEY must NOT be set, or Claude Code switches to pay-per-token
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "[ai-agent] FATAL: ANTHROPIC_API_KEY is set; this would override Pro subscription auth" >&2
  echo "[ai-agent] unset ANTHROPIC_API_KEY before continuing" >&2
  exit 3
fi

# Tool allowlist differs by mode. Reviews must not modify files.
if [[ "$MODE" == "review" ]]; then
  ALLOWED_TOOLS="Read,Grep,Glob,Bash"
  OPENCODE_MODEL_PRIMARY="${OPENCODE_MODEL_REVIEW:-opencode-go/glm-5.1}"
  OPENCODE_MODEL_SECONDARY=""
  OPENCODE_MODEL_TERTIARY=""
else
  ALLOWED_TOOLS="Read,Write,Edit,Grep,Glob,Bash"
  OPENCODE_MODEL_PRIMARY="${OPENCODE_MODEL_FIX_FREE:-opencode/deepseek-v4-flash-free}"
  OPENCODE_MODEL_SECONDARY="${OPENCODE_MODEL_FIX_GO:-opencode-go/qwen3.6-plus}"
  OPENCODE_MODEL_TERTIARY="${OPENCODE_MODEL_FIX_FALLBACK:-opencode-go/deepseek-v4-flash}"
fi

is_quota_or_overload_error() {
  local text="$1"
  echo "$text" | grep -qiE 'usage_limit|rate_limit|overloaded|insufficient_quota|429|529|billing|payment_required|reached your usage limit|quota|free.*limit|daily.*limit'
}

log() { echo "[ai-agent] $*" >&2; }

try_claude_code() {
  if ! command -v claude >/dev/null 2>&1; then
    log "claude CLI not found, skipping tier 1"
    return 2
  fi
  if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    log "CLAUDE_CODE_OAUTH_TOKEN not set, skipping tier 1"
    return 2
  fi
  log "tier 1: Claude Code via Pro subscription"
  local out exit_code
  set +e
  out=$(CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" \
        claude --print "$TASK" \
          --allowedTools "$ALLOWED_TOOLS" \
          --max-turns "$MAX_TURNS" \
          --output-format text \
          --dangerously-skip-permissions 2>&1)
  exit_code=$?
  set -e
  if is_quota_or_overload_error "$out"; then
    log "claude code: hit quota/overload, falling through to tier 2"
    return 1
  fi
  if [[ $exit_code -ne 0 ]]; then
    log "claude code exited $exit_code, falling through"
    log "stderr tail: $(echo "$out" | tail -5)"
    return 1
  fi
  echo "$out"
  return 0
}

try_opencode_model() {
  local model="$1"
  if ! command -v opencode >/dev/null 2>&1; then
    log "opencode CLI not found"
    return 2
  fi
  if [[ -z "${OPENCODE_API_KEY:-}" ]]; then
    log "OPENCODE_API_KEY not set, skipping opencode"
    return 2
  fi
  log "tier 2: OpenCode with model $model"
  local out exit_code
  set +e
  out=$(OPENCODE_API_KEY="$OPENCODE_API_KEY" \
        opencode run \
          --model "$model" \
          "$TASK" 2>&1)
  exit_code=$?
  set -e
  if is_quota_or_overload_error "$out"; then
    log "opencode $model: hit quota/limit, trying next model"
    return 1
  fi
  if [[ $exit_code -ne 0 ]]; then
    log "opencode $model exited $exit_code, trying next model"
    log "stderr tail: $(echo "$out" | tail -5)"
    return 1
  fi
  echo "$out"
  return 0
}

# Tier 1: Claude Code via Pro subscription
if try_claude_code; then exit 0; fi

# Tier 2: OpenCode with model cascade
if try_opencode_model "$OPENCODE_MODEL_PRIMARY"; then exit 0; fi
if [[ -n "$OPENCODE_MODEL_SECONDARY" ]]; then
  if try_opencode_model "$OPENCODE_MODEL_SECONDARY"; then exit 0; fi
fi
if [[ -n "$OPENCODE_MODEL_TERTIARY" ]]; then
  if try_opencode_model "$OPENCODE_MODEL_TERTIARY"; then exit 0; fi
fi

log "all tiers exhausted — manual intervention needed"
exit 1
