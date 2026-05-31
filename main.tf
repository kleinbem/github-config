terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Token from env: `export TF_VAR_github_tf_token=$(gh auth token)` works for an
# interactive run, or use a dedicated fine-grained PAT (see variables.tf).
provider "github" {
  owner = "kleinbem"
  token = var.github_tf_token
}
