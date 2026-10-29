default:
    @just --list

# --- Enforcement (declarative, OpenTofu; state in Cloudflare R2) ----------

# Init the R2 backend. Decrypts sops automatically if env vars are missing.
init:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    # kleinbem-secrets scopes credentials per-consumer (cutover 2026-08-08,
    # replaces nix-secrets' flat secrets.yaml): cloudflare_account_id is
    # core-pi's own (it owns the Cloudflare Tunnel), r2_state_* live in
    # infra/terraform.yaml.
    COREPI_SECRETS="../kleinbem-secrets/nix/per-host/core-pi.yaml"
    TERRAFORM_SECRETS="../kleinbem-secrets/infra/terraform.yaml"
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && [ -f "$COREPI_SECRETS" ] && [ -f "$TERRAFORM_SECRETS" ]; then
        echo "🔐 Decrypting R2 credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
        if COREPI_YAML=$(sops -d "$COREPI_SECRETS") && TERRAFORM_YAML=$(sops -d "$TERRAFORM_SECRETS"); then
            ACCOUNT_ID=$(echo "$COREPI_YAML" | yq '.cloudflare_account_id')
            KEY_ID=$(echo "$TERRAFORM_YAML" | yq '.r2_state_access_key_id')
            SECRET_KEY=$(echo "$TERRAFORM_YAML" | yq '.r2_state_secret_access_key')
            if [ -n "$ACCOUNT_ID" ] && [ "$ACCOUNT_ID" != "null" ]; then
                export CLOUDFLARE_ACCOUNT_ID="$ACCOUNT_ID"
                export AWS_ACCESS_KEY_ID="$KEY_ID"
                export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
            fi
        fi
    fi
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "${CLOUDFLARE_ACCOUNT_ID:-}" = "null" ]; then
        echo "❌ CLOUDFLARE_ACCOUNT_ID missing. Ensure kleinbem-secrets is available or export CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
    fi
    printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl

# Review planned GitHub config changes (imports + in-place updates only).
plan:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    COREPI_SECRETS="../kleinbem-secrets/nix/per-host/core-pi.yaml"
    TERRAFORM_SECRETS="../kleinbem-secrets/infra/terraform.yaml"
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && [ -f "$COREPI_SECRETS" ] && [ -f "$TERRAFORM_SECRETS" ]; then
        echo "🔐 Decrypting R2 credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
        COREPI_YAML=$(sops -d "$COREPI_SECRETS")
        TERRAFORM_YAML=$(sops -d "$TERRAFORM_SECRETS")
        export CLOUDFLARE_ACCOUNT_ID=$(echo "$COREPI_YAML" | yq '.cloudflare_account_id')
        export AWS_ACCESS_KEY_ID=$(echo "$TERRAFORM_YAML" | yq '.r2_state_access_key_id')
        export AWS_SECRET_ACCESS_KEY=$(echo "$TERRAFORM_YAML" | yq '.r2_state_secret_access_key')
    fi
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "${CLOUDFLARE_ACCOUNT_ID:-}" = "null" ]; then
        echo "❌ CLOUDFLARE_ACCOUNT_ID missing. Ensure kleinbem-secrets is available or export CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
    fi
    printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl
    source scripts/gh-app-env.sh
    $TOFU plan

# Apply the GitHub config (settings, rulesets, labels).
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    COREPI_SECRETS="../kleinbem-secrets/nix/per-host/core-pi.yaml"
    TERRAFORM_SECRETS="../kleinbem-secrets/infra/terraform.yaml"
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && [ -f "$COREPI_SECRETS" ] && [ -f "$TERRAFORM_SECRETS" ]; then
        echo "🔐 Decrypting R2 credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
        COREPI_YAML=$(sops -d "$COREPI_SECRETS")
        TERRAFORM_YAML=$(sops -d "$TERRAFORM_SECRETS")
        export CLOUDFLARE_ACCOUNT_ID=$(echo "$COREPI_YAML" | yq '.cloudflare_account_id')
        export AWS_ACCESS_KEY_ID=$(echo "$TERRAFORM_YAML" | yq '.r2_state_access_key_id')
        export AWS_SECRET_ACCESS_KEY=$(echo "$TERRAFORM_YAML" | yq '.r2_state_secret_access_key')
    fi
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "${CLOUDFLARE_ACCOUNT_ID:-}" = "null" ]; then
        echo "❌ CLOUDFLARE_ACCOUNT_ID missing. Ensure kleinbem-secrets is available or export CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
    fi
    printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl
    source scripts/gh-app-env.sh
    $TOFU apply

# Forget a repo's resources from state without touching GitHub (archived repos).
forget repo:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    COREPI_SECRETS="../kleinbem-secrets/nix/per-host/core-pi.yaml"
    TERRAFORM_SECRETS="../kleinbem-secrets/infra/terraform.yaml"
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] && [ -f "$COREPI_SECRETS" ] && [ -f "$TERRAFORM_SECRETS" ]; then
        echo "🔐 Decrypting R2 credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
        COREPI_YAML=$(sops -d "$COREPI_SECRETS")
        TERRAFORM_YAML=$(sops -d "$TERRAFORM_SECRETS")
        export CLOUDFLARE_ACCOUNT_ID=$(echo "$COREPI_YAML" | yq '.cloudflare_account_id')
        export AWS_ACCESS_KEY_ID=$(echo "$TERRAFORM_YAML" | yq '.r2_state_access_key_id')
        export AWS_SECRET_ACCESS_KEY=$(echo "$TERRAFORM_YAML" | yq '.r2_state_secret_access_key')
    fi
    if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ] || [ "${CLOUDFLARE_ACCOUNT_ID:-}" = "null" ]; then
        echo "❌ CLOUDFLARE_ACCOUNT_ID missing. Ensure kleinbem-secrets is available or export CLOUDFLARE_ACCOUNT_ID." >&2
        exit 1
    fi
    printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl
    mapfile -t addrs < <($TOFU state list | grep -F '["{{repo}}"]')
    if [ ${#addrs[@]} -eq 0 ]; then echo "Nothing in state for {{repo}}."; exit 0; fi
    printf '  %s\n' "${addrs[@]}"
    $TOFU state rm "${addrs[@]}"

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
