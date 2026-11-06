variable "repos" {
  description = "Repo name => merged settings (see repo_defaults in repos.tf)."
  type        = any
}

variable "standard_labels" {
  description = "Label set every repo gets, on top of each repo's extra_labels."
  type        = map(object({ color = string, description = string }))
}
