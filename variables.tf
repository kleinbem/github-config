# GitHub App credentials for `app_auth {}` in main.tf, set as TF_VAR_github_app_*
# (see main.tf). The R2 backend creds come from env instead (backend.tf).

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

# Ephemeral keeps the key out of saved plan files: apply's tfplan travels as a
# workflow artifact, which anyone can download from a public repo.
variable "github_app_pem" {
  type        = string
  sensitive   = true
  ephemeral   = true
  description = "GitHub App private key — PEM contents (not a path). Provider does the JWT → installation-token exchange."
}
