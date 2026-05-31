# ---------------------------------------------------------------------------
# Declarative config for the general kleinbem repos. Replaces the old
# audit_repos.py / sync_labels.py enforcement scripts with drift-free HCL.
# Repo map + labels live in repos.tf.
# ---------------------------------------------------------------------------

# Adopt existing repos (import, never create); prevent_destroy guards them.
import {
  for_each = local.repos
  to       = github_repository.this[each.key]
  id       = each.key
}

resource "github_repository" "this" {
  for_each = local.repos

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

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

  vulnerability_alerts = each.value.vulnerability_alerts

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
  }
}

# Dependabot automated security fixes (free for all repos; needs vuln alerts).
resource "github_repository_dependabot_security_updates" "this" {
  for_each = local.repos

  repository = github_repository.this[each.key].name
  enabled    = true
}

# Default-branch guardrails: block deletion + force-push, admin (you) bypasses
# so direct push to the default branch still works. Skipped for empty repos.
resource "github_repository_ruleset" "main" {
  for_each = { for n, c in local.repos : n => c if c.ruleset }

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
  }

  bypass_actors {
    actor_id    = 5 # Repository admin role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  depends_on = [github_repository.this]
}

# Standard label set, authoritative per repo (handles GitHub's default labels
# without per-label imports; reconciles to exactly this set).
resource "github_issue_labels" "this" {
  for_each   = local.repos
  repository = github_repository.this[each.key].name

  dynamic "label" {
    for_each = local.standard_labels
    content {
      name        = label.key
      color       = label.value.color
      description = label.value.description
    }
  }
}
