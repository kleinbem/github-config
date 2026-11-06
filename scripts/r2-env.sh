#!/usr/bin/env bash
# Sourced by the Justfile's tofu recipes: exports the R2 state backend's
# CLOUDFLARE_ACCOUNT_ID + AWS_* from kleinbem-secrets ($KLEINBEM_SECRETS_DIR)
# unless CLOUDFLARE_ACCOUNT_ID is already set, then writes .r2-endpoint.hcl.

_secrets_dir="${KLEINBEM_SECRETS_DIR:-../kleinbem-secrets}"
# cloudflare_account_id is core-pi's own (it owns the Cloudflare Tunnel);
# r2_state_* live in infra/terraform.yaml.
_corepi_secrets="$_secrets_dir/nix/per-host/core-pi.yaml"
_terraform_secrets="$_secrets_dir/infra/terraform.yaml"

if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
    if [ ! -f "$_corepi_secrets" ] || [ ! -f "$_terraform_secrets" ]; then
        echo "❌ R2 credentials not found under $_secrets_dir. Clone kleinbem-secrets or export CLOUDFLARE_ACCOUNT_ID + AWS_*." >&2
        return 1
    fi
    echo "🔐 Decrypting R2 credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
    _corepi_yaml=$(sops -d "$_corepi_secrets") || return 1
    _terraform_yaml=$(sops -d "$_terraform_secrets") || return 1
    CLOUDFLARE_ACCOUNT_ID=$(echo "$_corepi_yaml" | yq '.cloudflare_account_id')
    AWS_ACCESS_KEY_ID=$(echo "$_terraform_yaml" | yq '.r2_state_access_key_id')
    AWS_SECRET_ACCESS_KEY=$(echo "$_terraform_yaml" | yq '.r2_state_secret_access_key')
    export CLOUDFLARE_ACCOUNT_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
fi

for _v in CLOUDFLARE_ACCOUNT_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
    if [ -z "${!_v:-}" ] || [ "${!_v}" = "null" ]; then
        echo "❌ $_v is empty. Check kleinbem-secrets or export it." >&2
        return 1
    fi
done

printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
