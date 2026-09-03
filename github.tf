# ---------------------------------------------------------------------------
# Declarative config for the general kleinbem repos. Replaces the old
# audit_repos.py / sync_labels.py enforcement scripts with drift-free HCL.
# Repo map + labels live in repos.tf.
# ---------------------------------------------------------------------------

# Adopt existing repos (import); prevent_destroy guards them. Repos listed in
# local.repos_pending_create are skipped here so github_repository.this creates
# them on first apply instead of failing on a non-existent import target.
import {
  for_each = {
    for k, v in local.repos : k => v
    if !contains(local.repos_pending_create, k)
  }
  to = github_repository.this[each.key]
  id = each.key
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
  for_each   = { for k, v in local.repos : k => v if v.vulnerability_alerts }
  repository = github_repository.this[each.key].name
  enabled    = true
}

# Dependabot automated security fixes (free for all repos; needs vuln alerts).
resource "github_repository_dependabot_security_updates" "this" {
  for_each = local.repos

  repository = github_repository.this[each.key].name
  enabled    = true
}

# Default-branch guardrails: block deletion + force-push, admin (you) bypasses
# so direct push to the default branch still works. Rulesets are free for public repos.
resource "github_repository_ruleset" "main" {
  for_each = { for n, c in local.repos : n => c if c.ruleset && c.visibility == "public" }

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

    dynamic "required_status_checks" {
      for_each = length(each.value.required_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true
        dynamic "required_check" {
          for_each = each.value.required_checks
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
  for_each        = local.repos
  repository      = github_repository.this[each.key].name
  allowed_actions = "all"
}

# Standard label set, authoritative per repo (handles GitHub's default labels
# without per-label imports; reconciles to exactly this set).
resource "github_issue_labels" "this" {
  for_each   = local.repos
  repository = github_repository.this[each.key].name

  dynamic "label" {
    for_each = merge(local.standard_labels, each.value.extra_labels)
    content {
      name        = label.key
      color       = label.value.color
      description = label.value.description
    }
  }
}
