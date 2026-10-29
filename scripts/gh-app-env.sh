#!/usr/bin/env bash
# Sourced by `just plan` / `just apply` (never run directly).
#
# Exports the GitHub App credentials the tofu `github` provider reads for
# `app_auth {}` (see main.tf):
#   TF_VAR_github_app_id, TF_VAR_github_app_installation_id,
#   TF_VAR_github_app_org_installation_id, TF_VAR_github_app_pem
#
# Source of truth is kleinbem-secrets/nix/shared.yaml — the same file
# nix/tools/tf-apply.sh reads to distribute APP_ID / APP_INSTALLATION_ID /
# APP_PRIVATE_KEY to CI. Martin's YubiKeys are recipients on that file.
#
# Skips the sops call if TF_VAR_github_app_id is already set (lets a caller
# override for testing). The caller runs with `set -euo pipefail`, so a failure
# here aborts the recipe.

if [ -z "${TF_VAR_github_app_id:-}" ]; then
    _shared_secrets="../kleinbem-secrets/nix/shared.yaml"
    if [ ! -f "$_shared_secrets" ]; then
        echo "❌ $_shared_secrets not found — clone kleinbem-secrets beside github-config." >&2
        return 1
    fi
    echo "🔐 Decrypting GitHub App credentials from kleinbem-secrets (touch YubiKey if prompted)..." >&2
    _shared_yaml=$(sops -d "$_shared_secrets")

    TF_VAR_github_app_id=$(echo "$_shared_yaml" | yq '.github_app_id')
    TF_VAR_github_app_installation_id=$(echo "$_shared_yaml" | yq '.github_app_installation_id')
    TF_VAR_github_app_org_installation_id=$(echo "$_shared_yaml" | yq '.github_app_org_installation_id')
    TF_VAR_github_app_pem=$(echo "$_shared_yaml" | yq '.github_app_private_key')
    export TF_VAR_github_app_id TF_VAR_github_app_installation_id TF_VAR_github_app_org_installation_id TF_VAR_github_app_pem
fi

for _v in TF_VAR_github_app_id TF_VAR_github_app_installation_id TF_VAR_github_app_org_installation_id TF_VAR_github_app_pem; do
    if [ -z "${!_v:-}" ] || [ "${!_v}" = "null" ]; then
        echo "❌ $_v is empty — check github_app_{id,installation_id,org_installation_id,private_key} in kleinbem-secrets/nix/shared.yaml." >&2
        return 1
    fi
done
