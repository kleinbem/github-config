# GitHub App credentials the provider authenticates with (`app_auth {}` in
# main.tf). Set as TF_VAR_github_app_* by `just plan` / `just apply` (from
# kleinbem-secrets/nix/shared.yaml, via scripts/gh-app-env.sh) and by the
# terraform-{plan,apply}.yaml workflows (from Actions secrets). No PAT.
#
# The R2 state backend creds come from AWS_*/CLOUDFLARE_ACCOUNT_ID env, set the
# same two ways — see the Justfile and the workflows.

variable "github_app_id" {
  type        = string
  sensitive   = true
  description = "GitHub App ID (numeric)."
}

variable "github_app_installation_id" {
  type        = string
  sensitive   = true
  description = "Installation ID of the GitHub App on the kleinbem account."
}

variable "github_app_org_installation_id" {
  type        = string
  sensitive   = true
  description = "Installation ID of the same GitHub App on the kleinbem-dev organization (provider alias `org`)."
}

variable "github_app_pem" {
  type        = string
  sensitive   = true
  description = "GitHub App private key — PEM contents (not a path). Provider does the JWT → installation-token exchange."
}
