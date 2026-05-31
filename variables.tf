variable "github_tf_token" {
  type      = string
  sensitive = true
  # Fine-grained PAT (or `gh auth token`) with access to the managed general
  # repos and: Administration R/W (settings + rulesets), Issues R/W (labels),
  # Metadata R. No Secrets scope needed — this config distributes no Actions
  # secrets (those live in the nix workspace's terraform config).
  description = "GitHub token the provider authenticates with (fine-grained PAT or `gh auth token`)."
}
