terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# GitHub App auth, no PAT: the provider mints a short-lived installation token.
# Credentials come from scripts/gh-app-env.sh locally and the APP_* secrets in CI.
# Needs Administration R/W, Issues R/W, Metadata R. Apps can't create repos on a
# user account, so repos are created by hand and adopted by github.tf's import
# blocks; org repos stay adopt-only too so both owners work the same way.
provider "github" {
  owner = "kleinbem"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_installation_id
    pem_file        = var.github_app_pem
  }
}

# Same App, installed a second time on the kleinbem-dev organization. An
# installation is per account, so the org needs its own installation id (the
# App id and key are shared). Repos under the org are listed in
# local.org_repos (repos.tf).
provider "github" {
  alias = "org"
  owner = "kleinbem-dev"
  app_auth {
    id              = var.github_app_id
    installation_id = var.github_app_org_installation_id
    pem_file        = var.github_app_pem
  }
}
