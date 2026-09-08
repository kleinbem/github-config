terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Auth: a short-lived GitHub App installation token, minted by the provider
# itself from the App private key (JWT → installation-token exchange). Same
# identity locally and in CI — no long-lived PAT anywhere:
#
#   local : `just plan` / `just apply` decrypt github_app_{id,installation_id,
#           private_key} from kleinbem-secrets/nix/shared.yaml (via
#           scripts/gh-app-env.sh) and export them as TF_VAR_github_app_*.
#   CI    : terraform-{plan,apply}.yaml set the same TF_VAR_github_app_* from
#           the APP_ID / APP_INSTALLATION_ID / APP_PRIVATE_KEY Actions secrets
#           (distributed by nix/infra/github-secrets.tf).
#
# The App only needs Administration R/W + Issues R/W + Metadata R on the managed
# repos — repo *creation* is out of scope (Apps can't create repos on a user
# account; new repos are created out-of-band and adopted by the import block in
# github.tf).
provider "github" {
  owner = "kleinbem"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem
  }
}
