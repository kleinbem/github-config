# kleinbem-secrets sits next to the primary checkout, two levels up from an
# agent workspace (github-config.ws/<name>).
secrets := if path_exists(justfile_directory() / "../kleinbem-secrets") == "true" { justfile_directory() / "../kleinbem-secrets" } else { justfile_directory() / "../../kleinbem-secrets" }
# Read by scripts/r2-env.sh and scripts/gh-app-env.sh.
export KLEINBEM_SECRETS_DIR := secrets

default:
    @just --list

# --- Enforcement (declarative, OpenTofu; state in Cloudflare R2) ----------

# Init the R2 backend. Decrypts sops automatically if env vars are missing.
init:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    source scripts/r2-env.sh
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl

# Review planned GitHub config changes (imports + in-place updates only).
plan:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    source scripts/r2-env.sh
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl
    source scripts/gh-app-env.sh
    $TOFU plan

# Apply the GitHub config (settings, rulesets, labels).
apply:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    source scripts/r2-env.sh
    $TOFU init -input=false -backend-config=.r2-endpoint.hcl
    source scripts/gh-app-env.sh
    $TOFU apply

# Forget a repo's resources from state without touching GitHub (archived repos).
forget repo:
    #!/usr/bin/env bash
    set -euo pipefail
    TOFU=$(command -v tofu 2>/dev/null || echo "nix develop --command tofu")
    source scripts/r2-env.sh
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
