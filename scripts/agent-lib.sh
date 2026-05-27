#!/usr/bin/env bash
# Agent execution library — retry logic for ai-agent.sh and infrastructure ops.
# Source this file; do not execute it directly.
#
# ai-agent.sh exit codes:
#   0 = success
#   1 = all tiers exhausted (quota, rate limit, transient) → retry with backoff
#   2 = missing CLI or credentials → fail fast, no retry
#   3 = ANTHROPIC_API_KEY set (config error) → fail fast, no retry

set -euo pipefail

# ---------------------------------------------------------------------------
# retry_op <max_attempts> <base_delay_seconds> <command...>
# Generic retry with exponential backoff for infrastructure operations.
# ---------------------------------------------------------------------------
retry_op() {
  local max_attempts="$1"
  local base_delay="$2"
  shift 2
  local attempt=0
  local delay="$base_delay"

  while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    echo "▶ Attempt $attempt/$max_attempts: $*"
    if "$@"; then
      return 0
    fi
    if [ $attempt -lt $max_attempts ]; then
      echo "⏳ Failed — retrying in ${delay}s..."
      sleep "$delay"
      delay=$((delay * 2))
    fi
  done

  echo "::error::Command failed after $max_attempts attempts: $*"
  return 1
}

# ---------------------------------------------------------------------------
# run_agent_with_fallback <prompt_file> <mode> <max_turns>
#
# Calls ai-agent.sh which handles its own tier cascade internally.
# This function adds an outer retry loop for when all tiers are exhausted
# (typically an API outage or quota reset window).
#
# Retry strategy:
#   Within a cycle: up to MAX_RETRIES attempts, 30s → 60s → 120s backoff
#   Between cycles: 5min → 10min wait before cycling through tiers again
#   Max cycles: MAX_CYCLES
# ---------------------------------------------------------------------------
run_agent_with_fallback() {
  local prompt_file="$1"
  local mode="$2"
  local max_turns="$3"

  local MAX_RETRIES=3
  local BASE_DELAY=30        # doubles each retry within a cycle
  local MAX_CYCLES=3
  local CYCLE_BASE_DELAY=300 # 5min; doubles between cycles

  # Read prompt into a variable to pass to ai-agent.sh.
  # The 3000-line diff guard in the review workflow keeps this within safe limits.
  local task
  task=$(cat "$prompt_file")

  local cycle=0
  while [ $cycle -lt $MAX_CYCLES ]; do
    cycle=$((cycle + 1))

    if [ $cycle -gt 1 ]; then
      local cycle_wait=$(( CYCLE_BASE_DELAY * (2 ** (cycle - 2)) ))
      echo "::warning::All tiers exhausted on cycle $((cycle - 1)). Waiting ${cycle_wait}s before cycle $cycle..."
      sleep "$cycle_wait"
    fi

    local attempt=0
    local delay="$BASE_DELAY"

    while [ $attempt -lt $MAX_RETRIES ]; do
      attempt=$((attempt + 1))
      echo "🔄 Cycle $cycle, attempt $attempt/$MAX_RETRIES"

      local exit_code=0
      ./scripts/ai-agent.sh "$task" \
        --mode "$mode" \
        --max-turns "$max_turns" || exit_code=$?

      case $exit_code in
        0)
          echo "✅ Agent succeeded (cycle $cycle, attempt $attempt)"
          return 0
          ;;
        2)
          # Missing CLI or credentials — retrying won't help
          echo "::error::Agent exited 2: CLI not found or credentials missing."
          echo "::error::Check CLAUDE_CODE_OAUTH_TOKEN and OPENCODE_API_KEY secrets."
          return 2
          ;;
        3)
          # ANTHROPIC_API_KEY is set — configuration error, not transient
          echo "::error::Agent exited 3: ANTHROPIC_API_KEY must not be set."
          return 3
          ;;
        1)
          # All internal tiers exhausted — quota, rate limit, or outage
          if [ $attempt -lt $MAX_RETRIES ]; then
            echo "⏳ All tiers exhausted — retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
          fi
          ;;
        *)
          echo "::warning::Unexpected exit code $exit_code — treating as transient"
          if [ $attempt -lt $MAX_RETRIES ]; then
            sleep "$delay"
            delay=$((delay * 2))
          fi
          ;;
      esac
    done

    echo "❌ Cycle $cycle exhausted"
  done

  echo "::error::Agent failed across all $MAX_CYCLES retry cycles. Manual intervention required."
  return 1
}
