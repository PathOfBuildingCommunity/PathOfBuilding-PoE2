#!/usr/bin/env bash
# Agent execution library — retry logic, tier fallback, infrastructure retries.
# Source this file; do not execute it directly.
set -euo pipefail

# ---------------------------------------------------------------------------
# retry_op <max_attempts> <base_delay_seconds> <command...>
#
# Generic retry with exponential backoff for infrastructure operations
# (git push, gh pr create, gh pr comment, etc.)
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
# Tries each configured agent tier in order. Within each tier, retries up to
# MAX_TIER_RETRIES times with exponential backoff. If all tiers fail, waits
# and cycles through all tiers again up to MAX_CYCLES times.
#
# Exit codes from ai-agent.sh are classified as:
#   0  = success
#   2  = auth/credentials failure → skip to next tier immediately
#   *  = transient failure (rate limit, timeout, 5xx) → retry with backoff
# ---------------------------------------------------------------------------
run_agent_with_fallback() {
  local prompt_file="$1"
  local mode="$2"
  local max_turns="$3"

  local MAX_TIER_RETRIES=3
  local TIER_BASE_DELAY=30      # seconds; doubles each retry: 30 → 60 → 120
  local MAX_CYCLES=3
  local CYCLE_BASE_DELAY=300    # seconds between full cycles: 5min → 10min → 20min

  # Tier registry — each entry: "name|credential_var|extra_flags"
  # Add or reorder tiers here as your setup changes.
  local -a TIERS=(
    "claude-code-oauth|CLAUDE_CODE_OAUTH_TOKEN|"
    "opencode|OPENCODE_API_KEY|--agent opencode"
    # Opt-in emergency tiers: set EMERGENCY_ANTHROPIC_API_KEY in repo secrets.
    # Intentionally separate from ANTHROPIC_API_KEY to avoid accidental PAYG
    # on normal runs (the existing guard in the workflow protects that).
    "claude-sonnet|EMERGENCY_ANTHROPIC_API_KEY|--model claude-sonnet-4-5"
    "claude-haiku|EMERGENCY_ANTHROPIC_API_KEY|--model claude-haiku-3-5"
  )

  local cycle=0
  while [ $cycle -lt $MAX_CYCLES ]; do
    cycle=$((cycle + 1))

    if [ $cycle -gt 1 ]; then
      local cycle_wait=$(( CYCLE_BASE_DELAY * (2 ** (cycle - 2)) ))
      echo "::warning::All tiers exhausted on cycle $((cycle - 1)). Waiting ${cycle_wait}s before cycle $cycle..."
      sleep "$cycle_wait"
    fi

    local any_tier_available=false

    for tier_entry in "${TIERS[@]}"; do
      local tier_name
      local cred_var
      local extra_flags
      IFS='|' read -r tier_name cred_var extra_flags <<< "$tier_entry"

      # Resolve the credential variable
      local cred_value="${!cred_var:-}"
      if [[ -z "$cred_value" ]]; then
        echo "⏭ Tier '$tier_name': no credentials ($cred_var unset), skipping"
        continue
      fi
      any_tier_available=true

      echo "🔄 Cycle $cycle — Tier: $tier_name"
      local attempt=0
      local delay="$TIER_BASE_DELAY"
      local tier_succeeded=false

      while [ $attempt -lt $MAX_TIER_RETRIES ]; do
        attempt=$((attempt + 1))
        echo "  ↳ Attempt $attempt/$MAX_TIER_RETRIES"

        # Set the appropriate credential for this tier
        local agent_exit=0
        if [[ "$tier_name" == "claude-code-oauth" ]]; then
          CLAUDE_CODE_OAUTH_TOKEN="$cred_value" \
            ./scripts/ai-agent.sh \
              --prompt-file "$prompt_file" \
              --mode "$mode" \
              --max-turns "$max_turns" || agent_exit=$?
        elif [[ "$tier_name" == "opencode" ]]; then
          OPENCODE_API_KEY="$cred_value" \
            ./scripts/ai-agent.sh \
              --prompt-file "$prompt_file" \
              --mode "$mode" \
              --max-turns "$max_turns" \
              $extra_flags || agent_exit=$?
        else
          # Emergency API tiers — explicitly set the key under its real name
          ANTHROPIC_API_KEY="$cred_value" \
            ./scripts/ai-agent.sh \
              --prompt-file "$prompt_file" \
              --mode "$mode" \
              --max-turns "$max_turns" \
              $extra_flags || agent_exit=$?
        fi

        if [ $agent_exit -eq 0 ]; then
          echo "✅ Agent succeeded — Tier: $tier_name, Cycle: $cycle, Attempt: $attempt"
          return 0
        fi

        # Exit code 2 = auth/credential failure — no point retrying this tier
        if [ $agent_exit -eq 2 ]; then
          echo "⚠️ Auth failure on tier '$tier_name' (exit 2) — moving to next tier"
          break
        fi

        if [ $attempt -lt $MAX_TIER_RETRIES ]; then
          echo "  ⏳ Transient failure (exit $agent_exit) — retrying in ${delay}s..."
          sleep "$delay"
          delay=$((delay * 2))
        fi
      done

      echo "❌ Tier '$tier_name' exhausted after $attempt attempt(s)"
    done

    if [ "$any_tier_available" = false ]; then
      echo "::error::No agent tiers have credentials configured. Check your repository secrets."
      return 1
    fi

    echo "::warning::All available tiers failed on cycle $cycle"
  done

  echo "::error::Agent failed across all tiers and all $MAX_CYCLES retry cycles. Manual intervention required."
  return 1
}
