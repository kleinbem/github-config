default:
    @just --list

# --- Enforcement (declarative, OpenTofu; state in Cloudflare R2) ----------

# Init the R2 backend. Decrypts sops automatically if env vars are missing.
init:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    SECRETS="../nix/nix-secrets/secrets.yaml"
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && [ -f "$SECRETS" ]; then
        echo "🔐 Decrypting R2 credentials from nix-secrets (touch YubiKey if prompted)..." >&2
        if YAML=$(sops -d "$SECRETS"); then
            ACCOUNT_ID=$(echo "$YAML" | yq '.cloudflare_account_id')
            KEY_ID=$(echo "$YAML" | yq '.r2_state_access_key_id')
            SECRET_KEY=$(echo "$YAML" | yq '.r2_state_secret_access_key')
            if [ -n "$ACCOUNT_ID" ] && [ "$ACCOUNT_ID" != "null" ]; then
                export CLOUDFLARE_ACCOUNT_ID="$ACCOUNT_ID"
                export AWS_ACCESS_KEY_ID="$KEY_ID"
                export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
            fi
        fi
    fi
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "${CLOUDFLARE_ACCOUNT_ID:-}" = "null" ]; then
        echo "❌ CLOUDFLARE_ACCOUNT_ID missing. Ensure nix-secrets is available or export CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
    fi
    printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl

# Review planned GitHub config changes (imports + in-place updates only).
plan: init
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    SECRETS="../nix/nix-secrets/secrets.yaml"
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -f "$SECRETS" ]; then
        if YAML=$(sops -d "$SECRETS"); then
            export AWS_ACCESS_KEY_ID=$(echo "$YAML" | yq '.r2_state_access_key_id')
            export AWS_SECRET_ACCESS_KEY=$(echo "$YAML" | yq '.r2_state_secret_access_key')
        fi
    fi
    TF_VAR_github_tf_token="$(gh auth token)" $TOFU plan

# Apply the GitHub config (settings, rulesets, labels).
apply: init
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    SECRETS="../nix/nix-secrets/secrets.yaml"
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -f "$SECRETS" ]; then
        if YAML=$(sops -d "$SECRETS"); then
            export AWS_ACCESS_KEY_ID=$(echo "$YAML" | yq '.r2_state_access_key_id')
            export AWS_SECRET_ACCESS_KEY=$(echo "$YAML" | yq '.r2_state_secret_access_key')
        fi
    fi
    TF_VAR_github_tf_token="$(gh auth token)" $TOFU apply

# One-time: migrate the existing local state into R2.
migrate-state: init
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    $TOFU init -migrate-state -backend-config=.r2-endpoint.hcl

# --- Observability (read-only reporting) -----------------------------------

# Regenerate DASHBOARD.md + governance-report.json.
report:
    python3 scripts/govern.py report

# Append today's traffic stats to traffic_data/.
traffic:
    python3 scripts/govern.py traffic

# Meta workspace jj operation forwarders:
status-all:
    @if [ -f ../justfile ]; then just -f ../justfile jj::status-all; else jj status; fi

save-all message="":
    @if [ -f ../justfile ]; then just -f ../justfile jj::save-all "{{message}}"; else jj describe -m "{{message}}"; fi

diff-all *args="":
    @if [ -f ../justfile ]; then just -f ../justfile jj::diff-all {{args}}; else jj diff {{args}}; fi

pull-all:
    @if [ -f ../justfile ]; then just -f ../justfile jj::pull-all; else jj git fetch && jj rebase -d main@origin; fi

push-all:
    @if [ -f ../justfile ]; then just -f ../justfile jj::push-all; else jj git push; fi

# Describe, sign, and push across the workspace using the meta jj::ship workflow.
ship message="":
    @if [ -f ../justfile ]; then just -f ../justfile jj::ship "{{message}}"; else git commit -a -m "{{message}}" && git push origin main; fi
