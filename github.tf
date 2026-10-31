# ---------------------------------------------------------------------------
# Declarative config for the general kleinbem repos. Replaces the old
# audit_repos.py / sync_labels.py enforcement scripts with drift-free HCL.
# Repo maps + labels live in repos.tf; the per-repo resources in
# modules/repos, instantiated once per owner below.
# ---------------------------------------------------------------------------

# Adopt existing repos (import, never create); prevent_destroy guards them.
import {
  for_each = local.repos
  to       = module.user.github_repository.this[each.key]
  id       = each.key
}

import {
  for_each = local.org_repos
  to       = module.org.github_repository.this[each.key]
  id       = each.key
}

# The kleinbem user account: the fleet and everything personal.
module "user" {
  source          = "./modules/repos"
  repos           = local.repos
  standard_labels = local.standard_labels
}

# The kleinbem-dev organization: projects meant for others (see repos.tf).
module "org" {
  source          = "./modules/repos"
  repos           = local.org_repos
  standard_labels = local.standard_labels
  providers = {
    github = github.org
  }
}

# 2026-10-29: the resources moved from the root into module.user unchanged;
# these keep the state entries, so the move plans as a no-op.
moved {
  from = github_repository.this
  to   = module.user.github_repository.this
}
moved {
  from = github_repository_vulnerability_alerts.this
  to   = module.user.github_repository_vulnerability_alerts.this
}
moved {
  from = github_repository_dependabot_security_updates.this
  to   = module.user.github_repository_dependabot_security_updates.this
}
moved {
  from = github_repository_ruleset.main
  to   = module.user.github_repository_ruleset.main
}
moved {
  from = github_actions_repository_permissions.this
  to   = module.user.github_actions_repository_permissions.this
}
moved {
  from = github_issue_labels.this
  to   = module.user.github_issue_labels.this
}

# A repo transferred from the user account to the org keeps its GitHub ids
# (ruleset included), so its state entries move across too instead of being
# forgotten and re-imported. One block per resource and repo; the transfer
# itself is a manual step (`gh api -X POST repos/kleinbem/<repo>/transfer
# -f new_owner=kleinbem-dev`), done before this moves.
moved {
  from = module.user.github_repository.this["nix-gantry"]
  to   = module.org.github_repository.this["nix-gantry"]
}
moved {
  from = module.user.github_repository_vulnerability_alerts.this["nix-gantry"]
  to   = module.org.github_repository_vulnerability_alerts.this["nix-gantry"]
}
moved {
  from = module.user.github_repository_dependabot_security_updates.this["nix-gantry"]
  to   = module.org.github_repository_dependabot_security_updates.this["nix-gantry"]
}
moved {
  from = module.user.github_repository_ruleset.main["nix-gantry"]
  to   = module.org.github_repository_ruleset.main["nix-gantry"]
}
moved {
  from = module.user.github_actions_repository_permissions.this["nix-gantry"]
  to   = module.org.github_actions_repository_permissions.this["nix-gantry"]
}
moved {
  from = module.user.github_issue_labels.this["nix-gantry"]
  to   = module.org.github_issue_labels.this["nix-gantry"]
}

# .github (the org profile README), transferred 2026-10-29.
moved {
  from = module.user.github_repository.this[".github"]
  to   = module.org.github_repository.this[".github"]
}
moved {
  from = module.user.github_repository_vulnerability_alerts.this[".github"]
  to   = module.org.github_repository_vulnerability_alerts.this[".github"]
}
moved {
  from = module.user.github_repository_dependabot_security_updates.this[".github"]
  to   = module.org.github_repository_dependabot_security_updates.this[".github"]
}
moved {
  from = module.user.github_repository_ruleset.main[".github"]
  to   = module.org.github_repository_ruleset.main[".github"]
}
moved {
  from = module.user.github_actions_repository_permissions.this[".github"]
  to   = module.org.github_actions_repository_permissions.this[".github"]
}
moved {
  from = module.user.github_issue_labels.this[".github"]
  to   = module.org.github_issue_labels.this[".github"]
}

# nix-holds, transferred 2026-10-31.
moved {
  from = module.user.github_repository.this["nix-holds"]
  to   = module.org.github_repository.this["nix-holds"]
}
moved {
  from = module.user.github_repository_vulnerability_alerts.this["nix-holds"]
  to   = module.org.github_repository_vulnerability_alerts.this["nix-holds"]
}
moved {
  from = module.user.github_repository_dependabot_security_updates.this["nix-holds"]
  to   = module.org.github_repository_dependabot_security_updates.this["nix-holds"]
}
moved {
  from = module.user.github_repository_ruleset.main["nix-holds"]
  to   = module.org.github_repository_ruleset.main["nix-holds"]
}
moved {
  from = module.user.github_actions_repository_permissions.this["nix-holds"]
  to   = module.org.github_actions_repository_permissions.this["nix-holds"]
}
moved {
  from = module.user.github_issue_labels.this["nix-holds"]
  to   = module.org.github_issue_labels.this["nix-holds"]
}
