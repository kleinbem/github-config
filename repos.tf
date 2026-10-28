# ---------------------------------------------------------------------------
# Single source of truth for ALL owned kleinbem repos' GitHub config (settings,
# rulesets, labels, security). This repo is PRIVATE, so it safely declares
# private repos too.
#
# Split of responsibility: this repo owns repo *config*; the nix meta-workspace's
# terraform/ owns only the Actions *secret* distribution for its CI repos (those
# values come from sops and must run where sops is). Forks and the throwaway
# `test` repo are excluded. Empty repos get no ruleset (no default branch yet).
#
# Settings normalise to best practice; `description`/`visibility` mirror current
# GitHub state so the first apply only normalises and never clears/flips.
# ---------------------------------------------------------------------------

locals {
  repo_defaults = {
    visibility                  = "public"
    has_issues                  = true
    has_wiki                    = false
    has_projects                = false
    allow_squash_merge          = true
    allow_merge_commit          = false
    allow_rebase_merge          = false
    allow_auto_merge            = true
    allow_update_branch         = true
    delete_branch_on_merge      = true
    squash_merge_title          = "PR_TITLE"
    squash_merge_message        = "PR_BODY"
    vulnerability_alerts        = true
    web_commit_signoff_required = true # DCO sign-off for any web-UI commits
    ruleset                     = true
    required_checks             = []
    bypass_apps                 = [] # list of GitHub App installation IDs for ruleset bypass (e.g. lockfile-autopilot)
    topics                      = [] # per-repo overrides via repo_overrides
    extra_labels                = {} # per-repo labels on top of standard_labels (see nix-packages)
  }

  repo_overrides = {
    # allow_auto_merge: GitHub silently won't persist this as true on private
    # repos on this account's plan (PATCH returns 200 but the field reverts) —
    # declaring false here matches reality so `tofu plan` stops reporting
    # permanent phantom drift. Same override on kleinbem-secrets below.
    "github-config" = {
      description      = "Declarative GitHub-as-code: repo settings, rulesets, labels (Terraform) + governance reporting"
      visibility       = "private"
      allow_auto_merge = false
    }
    "kleinbem" = { description = "It's me!" }
    # openwrt meta-workspace repos (mirrors the nix meta-workspace layout).
    # Public as a portfolio piece: secret-relevant values (SSID, passphrase,
    # lease MACs) live in kleinbem-secrets; the public repos hold only structure.
    "openwrt" = {
      description = "OpenWrt meta-workspace — tooling orchestrator for router firmware, config, and secrets"
      topics      = ["openwrt", "ansible", "infrastructure-as-code", "homelab", "monorepo", "jujutsu"]
    }
    "openwrt-builder" = {
      description     = "OpenWrt image builder"
      required_checks = ["validate"] # job in build.yml; the build-firmware matrix names change per profile
    }
    "openwrt-config" = {
      description     = "Managing OpenWRT network"
      required_checks = ["lint"] # job name in .github/workflows/ci.yaml
    }
    # openwrt-secrets deleted 2026-08-08 — fully replaced by kleinbem-secrets
    # (content migrated, every consumer repointed). Local backup kept at
    # ../openwrt-secrets.deleted.

    # nix meta-workspace repos (config here; their Actions secrets live in nix/terraform).
    # Public ones get portfolio topics so they surface in GitHub search/discovery.
    "nix" = {
      description     = "nix workspace"
      required_checks = ["check"] # job name in .github/workflows/ci.yaml (infra/ + tools/ checks)
      topics          = ["nixos", "nix-flakes", "infrastructure-as-code", "homelab", "monorepo", "jujutsu"]
    }
    "nix-config" = {
      description     = "nix-config"
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "homelab", "home-manager", "nixos-config"]
      extra_labels = {
        # Filed by the daily Vaultwarden version-drift watcher.
        "vaultwarden-version" = { color = "BFD4F2", description = "Auto-filed: shipped Vaultwarden is behind upstream" }
      }
    }
    "nix-packages" = {
      description     = "Nix User Repository (NUR)"
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nur"]
      # update-antigravity.yaml / update-langfuse.yaml tag their auto-PRs with
      # these via peter-evans/create-pull-request, which requires the label
      # to already exist. github_issue_labels is exhaustive per repo, so
      # leaving them undeclared deletes them and breaks both workflows next
      # run. Colors match what's live today.
      extra_labels = {
        "automated"   = { color = "ededed", description = "Opened automatically by a bot workflow" }
        "antigravity" = { color = "ededed", description = "Antigravity IDE/CLI update PRs" }
        # Created by Dependabot for its GitHub Actions update PRs.
        "github_actions" = { color = "000000", description = "Pull requests that update GitHub Actions code" }
      }
    }
    "nix-devshells" = {
      description     = "Isolated dev environments"
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "devenv", "dev-shells"]
    }
    "nix-holds" = {
      description     = "Packages the kleinbem fleet holds back from nixos-unstable, with release and alert workflows"
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nixpkgs"]
    }
    "nix-presets" = {
      description     = "Reusable NixOS modules, hardened security policies, and Nixpak sandboxes."
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nixos-modules", "containers", "nixpak"]
    }
    "nix-gantry" = {
      description     = "CI builds once; hosts fetch a manifest and atomically swap in a NixOS/systemd-nspawn container. No evaluation or building on the host."
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nixos-modules", "containers", "systemd"]
    }
    "nix-hardware" = {
      description     = "A library of NixOS hardware modules."
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nixos-modules", "hardware"]
    }
    "nix-templates" = {
      description     = "Reproducible development environments and Flake templates for instant project bootstrapping."
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "templates", "scaffolding"]
    }
    # nix-secrets deleted 2026-08-08 — fully replaced by kleinbem-secrets
    # (cutover done, zero live consumers left). Local backup kept at
    # ../nix-secrets.deleted.
    #
    # Single sops-encrypted vault for the whole fleet — nix, openwrt,
    # CI/infra, personas. See its own README.md for the design rationale.
    # allow_auto_merge: see github-config's override above — same
    # non-persisting-on-private-repos behavior applies here too.
    "kleinbem-secrets" = {
      description      = "Single encrypted secrets vault for the kleinbem workspace family (nix, openwrt, CI/infra, personas)"
      visibility       = "private"
      allow_auto_merge = false
    }
    "kleinbem-site" = {
      description     = "kleinbem.dev — personal site (Astro + Svelte + Tailwind)"
      required_checks = ["build"] # job name in kleinbem-site/.github/workflows/ci.yaml
      topics          = ["astro", "svelte", "tailwindcss", "personal-website"]
      extra_labels = {
        # Created by Dependabot for its npm update PRs.
        "javascript" = { color = "168700", description = "Pull requests that update javascript code" }
      }
    }
    "kleinbem-auth" = {
      description     = "Self-hosted auth (better-auth) for kleinbem.dev — Google/Facebook/etc. login for site visitors"
      required_checks = ["build"] # job name in .github/workflows/ci.yml
      topics          = ["better-auth", "nodejs", "sqlite", "oauth"]
    }
    "skills" = {
      description     = "Agent skills (Claude Code plugin marketplace): nixpkgs contributions, kleinbem fleet"
      required_checks = ["check"] # job name in .github/workflows/ci.yaml
      topics          = ["claude-code", "agent-skills", "nixpkgs"]
    }
    "mesh-llm-ci" = {
      description = "Run Mesh-LLM crate checks and tests on GitHub's Windows and macOS runners for any fork commit, before opening an upstream PR."
      topics      = ["mesh-llm", "github-actions", "ci"]
    }
    # GPU tests of nixpkgs' mesh-llm on the Orin's self-hosted runner. Private:
    # a self-hosted runner must never take jobs from a public repo's PRs.
    "mesh-llm-gpu" = {
      description      = "GPU tests of nixpkgs' mesh-llm on a self-hosted Jetson runner (the GPU half of the nix-packages canary)."
      visibility       = "private"
      allow_auto_merge = false
      topics           = ["mesh-llm", "github-actions", "ci", "cuda"]
    }
    "mesh-agents" = {
      description     = "Private, self-hosted AI agents that share compute across your devices."
      required_checks = ["check"]
      topics          = ["nixos", "nix-flakes", "nixos-modules", "ai-agents", "llm", "local-llm", "self-hosted", "mesh-llm", "goose"]
    }
    "chrome-open-in-app" = {
      description     = "Move browser tabs into standalone PWA/app windows (Chrome extension + Go native host)"
      required_checks = ["Lint, Test & Validate"] # job name in .github/workflows/ci.yaml
      topics          = ["chrome-extension", "pwa", "native-messaging", "golang"]
    }
    "aur-packages" = {
      description = "Arch Linux PKGBUILDs for the AUR, built and checked in clean containers."
      topics      = ["archlinux", "aur", "pkgbuild"]
    }
    # Adopted 2026-10-24: these four were created out-of-band and never
    # declared here, so they sat on GitHub's defaults — no auto-merge, no
    # delete-branch-on-merge, merge commits and rebase merges allowed, no
    # ruleset. None has CI yet, so no required_checks.
    "jj-toolbox" = {
      description = "Portable jj (Jujutsu) helpers"
      topics      = ["jujutsu", "jj", "git", "cli"]
    }
    "nix-toolbox" = {
      description = "Portable Nix flake dev-workflow tools"
      topics      = ["nix", "nix-flakes", "cli"]
    }
    "android-config" = {
      description = "Declarative Android fleet configuration, ADB tuning, and Termux management"
      topics      = ["android", "adb", "termux", "homelab"]
    }
    ".github" = {
      description = "Org profile README for the kleinbem fleet"
    }
    # Shared composite actions (nix-setup), consumed by sha pin from every
    # nix repo. Renamed from the empty kleinbem-actions placeholder.
    "actions" = {
      description     = "Shared GitHub Actions for the kleinbem repos (nix-setup: Determinate Nix + mesh-only Attic cache)"
      required_checks = ["actionlint", "smoke", "smoke-full", "smoke-arm"] # jobs in .github/workflows/ci.yaml
      topics          = ["github-actions", "composite-action", "nix", "ci"]
      extra_labels = {
        # Created by Dependabot for its GitHub Actions update PRs.
        "github_actions" = { color = "000000", description = "Pull requests that update GitHub Actions code" }
      }
    }
  }

  repos = {
    for name, ov in local.repo_overrides : name => merge(local.repo_defaults, ov)
  }

  # Standard label set (migrated from labels.yaml). Same set the nix config uses.
  standard_labels = {
    "bug"              = { color = "d73a4a", description = "Something isn't working" }
    "documentation"    = { color = "0075ca", description = "Improvements or additions to documentation" }
    "duplicate"        = { color = "cfd3d7", description = "This issue or pull request already exists" }
    "enhancement"      = { color = "a2eeef", description = "New feature or request" }
    "good first issue" = { color = "7057ff", description = "Good for newcomers" }
    "help wanted"      = { color = "008672", description = "Extra attention is needed" }
    "invalid"          = { color = "e4e669", description = "This doesn't seem right" }
    "question"         = { color = "d876e3", description = "Further information is requested" }
    "wontfix"          = { color = "ffffff", description = "This will not be worked on" }
    "security"         = { color = "ff0000", description = "Security vulnerability or enhancement" }
    "dependencies"     = { color = "0366d6", description = "Pull requests that update a dependency" }
  }

}
