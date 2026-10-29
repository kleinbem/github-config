# ---------------------------------------------------------------------------
# One owner's repos: settings, security, rulesets, Actions policy, labels.
# Instantiated once per GitHub owner from the root (github.tf): the kleinbem
# user account and the kleinbem-dev organization. A provider config is fixed
# per resource block, so one owner per module instance is the only way to keep
# the repo list a single map per owner. Imports stay in the root (import
# blocks can't live in modules).
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
  }
}

resource "github_repository" "this" {
  for_each = var.repos

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility
  archived    = each.value.archived

  has_issues   = each.value.has_issues
  has_wiki     = each.value.has_wiki
  has_projects = each.value.has_projects

  allow_squash_merge     = each.value.allow_squash_merge
  allow_merge_commit     = each.value.allow_merge_commit
  allow_rebase_merge     = each.value.allow_rebase_merge
  allow_auto_merge       = each.value.allow_auto_merge
  allow_update_branch    = each.value.allow_update_branch
  delete_branch_on_merge = each.value.delete_branch_on_merge

  # Clean squash commits: PR title as subject, PR body as the message.
  squash_merge_commit_title   = each.value.squash_merge_title
  squash_merge_commit_message = each.value.squash_merge_message

  # DCO-style sign-off required for any commits made via the GitHub web UI.
  # Has no effect on git-pushed commits — those are governed by the ruleset
  # below (required_signatures).
  web_commit_signoff_required = each.value.web_commit_signoff_required

  # Portfolio discoverability — topics make public repos surface in GitHub
  # search + tag-based browsing. Empty list = no topics.
  topics = each.value.topics

  # Secret scanning + push protection are free on public repos; private repos
  # need GitHub Advanced Security, so only enable on public ones.
  dynamic "security_and_analysis" {
    for_each = each.value.visibility == "public" ? [1] : []
    content {
      secret_scanning {
        status = "enabled"
      }
      secret_scanning_push_protection {
        status = "enabled"
      }
    }
  }

  lifecycle {
    prevent_destroy = true
    # template: create-time-only provenance (which template repo a repo was
    # generated from, e.g. nix-packages <- nix-community/nur-packages-template).
    # GitHub has no API to clear it post-creation, so it's not something
    # repos.tf ever declares — ignore it so tofu plan stops proposing the
    # same never-applicable removal on every run.
    ignore_changes = [template]
  }
}

# Vulnerability alerts per repository (replaces deprecated in-resource attribute).
resource "github_repository_vulnerability_alerts" "this" {
  for_each   = { for k, v in var.repos : k => v if v.vulnerability_alerts }
  repository = github_repository.this[each.key].name
  enabled    = true
}

# Dependabot automated security fixes (free for all repos; needs vuln alerts).
resource "github_repository_dependabot_security_updates" "this" {
  for_each = var.repos

  repository = github_repository.this[each.key].name
  enabled    = true
}

locals {
  ruleset_checks = {
    for n, c in var.repos : n => concat(c.required_checks, c.coderabbit ? ["CodeRabbit"] : [])
  }
}

# Default-branch guardrails: block deletion + force-push, admin (you) bypasses
# so direct push to the default branch still works. Rulesets are free for public repos.
resource "github_repository_ruleset" "main" {
  for_each = { for n, c in var.repos : n => c if c.ruleset && c.visibility == "public" }

  name        = "default-branch-guardrails"
  repository  = each.key
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true
    # Require GPG/SSH signature on every commit landing on the default branch.
    # Paired with jj's `signing.behavior = "own"` + the V2 SSH-FIDO NoTouch key,
    # this is touchless. See nix-presets/git.nix for the jj-side config.
    required_signatures = true

    # CodeRabbit reviews every PR (central config: <owner>/coderabbit). Its
    # findings block the merge until fixed or answered and resolved; its
    # check holds auto-merge until the review is in. Bot PRs and bot-pushed
    # heads report "skipped", and a rate-limited review passes, so neither
    # ever stalls a PR.
    dynamic "pull_request" {
      for_each = each.value.coderabbit ? [1] : []
      content {
        required_approving_review_count   = 0
        required_review_thread_resolution = true
        dismiss_stale_reviews_on_push     = false
        require_code_owner_review         = false
        require_last_push_approval        = false
      }
    }

    dynamic "required_status_checks" {
      for_each = length(local.ruleset_checks[each.key]) > 0 ? [1] : []
      content {
        # Not strict: GitHub auto-merge never updates a PR that fell behind
        # main, and main moves several times a day (docs syncs, lock bumps), so
        # strict mode left armed PRs stuck BEHIND. A green PR merges as is;
        # main's own CI (and nix-config's promote gate before any device)
        # catches the rare pair of PRs that only break together.
        strict_required_status_checks_policy = false
        dynamic "required_check" {
          for_each = local.ruleset_checks[each.key]
          content {
            context = required_check.value
          }
        }
      }
    }
  }

  bypass_actors {
    actor_id    = 5 # Repository admin role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  dynamic "bypass_actors" {
    for_each = each.value.bypass_apps
    content {
      actor_id    = bypass_actors.value
      actor_type  = "Integration"
      bypass_mode = "always"
    }
  }

  depends_on = [github_repository.this]
}

# GitHub Actions permissions policy (authoritative per repo).
resource "github_actions_repository_permissions" "this" {
  for_each        = var.repos
  repository      = github_repository.this[each.key].name
  allowed_actions = "all"
}

# Standard label set, authoritative per repo (handles GitHub's default labels
# without per-label imports; reconciles to exactly this set).
resource "github_issue_labels" "this" {
  for_each   = var.repos
  repository = github_repository.this[each.key].name

  dynamic "label" {
    for_each = merge(var.standard_labels, each.value.extra_labels)
    content {
      name        = label.key
      color       = label.value.color
      description = label.value.description
    }
  }
}
