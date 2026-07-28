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
  }

  repo_overrides = {
    "chromeos-vm-kernel"   = { description = "Custom ChromeOS VM kernel" }
    "CodeReview"           = { description = "", visibility = "private" }
    "dotfiles"             = { description = "dotfiles", visibility = "private" }
    "evidence"             = { description = "", visibility = "private" }
    "geminiapidemo"        = { description = "", visibility = "private" }
    "github-config"        = { description = "Declarative GitHub-as-code: repo settings, rulesets, labels (Terraform) + governance reporting", visibility = "private" }
    "kleinbem"             = { description = "It's me!" }
    "kleinbem-ublue-build" = { description = "A personal OS image built with BlueBuild, based on bluefin-dx. Contains custom configurations, scripts, and tools for my development workflow." }
    "kleinbem-ublue"       = { description = "My personal Universal Blue image, based on bluefin-dx. Contains custom configurations, scripts, and tools for my development workflow. " }
    "nix-redroid-setup"    = { description = "Declarative build system for Redroid OCI images" }
    "nix-waydroid-setup"   = { description = "Automated Waydroid setup for NixOS" }
    # openwrt meta-workspace repos (mirrors the nix meta-workspace layout).
    # Public as a portfolio piece: secret-relevant values (SSID, passphrase,
    # lease MACs) live in openwrt-secrets; the public repos hold only structure.
    "openwrt" = {
      description = "OpenWrt meta-workspace — tooling orchestrator for router firmware, config, and secrets"
      topics      = ["openwrt", "ansible", "infrastructure-as-code", "homelab", "monorepo", "jujutsu"]
    }
    "openwrt-builder"               = { description = "OpenWrt image builder" }
    "openwrt-config"                = { description = "Managing OpenWRT network" }
    "openwrt-secrets"               = { description = "", visibility = "private" }
    "rename-window-gnome-extension" = { description = "" }

    # nix meta-workspace repos (config here; their Actions secrets live in nix/terraform).
    # Public ones get portfolio topics so they surface in GitHub search/discovery.
    "nix" = {
      description     = "nix workspace"
      required_checks = ["System Integration & VM Tests", "Lint & Format Audit"]
      topics          = ["nixos", "nix-flakes", "infrastructure-as-code", "homelab", "monorepo", "jujutsu"]
    }
    "nix-config" = {
      description = "nix-config"
      topics      = ["nixos", "nix-flakes", "homelab", "home-manager", "nixos-config"]
    }
    "nix-packages" = {
      description = "Nix User Repository (NUR)"
      topics      = ["nixos", "nix-flakes", "nur"]
    }
    "nix-devshells" = {
      description = "Isolated dev environments"
      topics      = ["nixos", "nix-flakes", "devenv", "dev-shells"]
    }
    "nix-presets" = {
      description = "Reusable NixOS modules, hardened security policies, and Nixpak sandboxes."
      topics      = ["nixos", "nix-flakes", "nixos-modules", "containers", "nixpak"]
    }
    "nix-hardware" = {
      description = "A library of NixOS hardware modules."
      topics      = ["nixos", "nix-flakes", "nixos-modules", "hardware"]
    }
    "nix-templates" = {
      description = "Reproducible development environments and Flake templates for instant project bootstrapping."
      topics      = ["nixos", "nix-flakes", "templates", "scaffolding"]
    }
    "nix-secrets" = { description = "Encrypted secrets for declarative NixOS configuration", visibility = "private" }
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
