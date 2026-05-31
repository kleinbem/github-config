# GitHub Governance & Configuration

Declarative GitHub-as-code for the **general** `kleinbem` repos (the nix
workspace repos are managed from the [`nix`](https://github.com/kleinbem/nix)
meta-repo's `terraform/`). Two halves:

| Half | Tooling | What |
|---|---|---|
| **Enforcement** (drift-free) | Terraform (`*.tf`) | repo settings, default-branch rulesets, standard labels, secret scanning + Dependabot |
| **Observability** (read-only) | `scripts/govern.py` + weekly Action | `DASHBOARD.md`, traffic archive |

This replaces the earlier imperative Python+`gh` enforcement scripts (preserved
on the `archive/script-era-wip` branch).

## Enforcement (Terraform)

Repos and their settings are declared in `repos.tf`; resources in `github.tf`.
Existing repos are **adopted via `import` blocks** — the first apply normalises
settings, it never creates or destroys.

```bash
nix develop                                  # tofu, gh, python
export TF_VAR_github_tf_token=$(gh auth token)   # or a fine-grained PAT
tofu init
tofu plan      # REVIEW: expect imports + in-place updates, zero destroy/create
tofu apply
```

Token needs Administration R/W (settings + rulesets), Issues R/W (labels),
Metadata R across the managed repos.

## Observability (`govern.py`)

```bash
just report     # regenerate DASHBOARD.md + governance-report.json
just traffic    # append today's views/clones to traffic_data/
```

Runs weekly via `.github/workflows/governance.yaml` (needs a read-only
`GOVERNANCE_PAT` secret with Metadata + Contents read on all repos).

## Configuration

- **Repos / settings**: `repos.tf` (one map entry per repo; `repo_defaults` for
  the baseline).
- **Labels**: `local.standard_labels` in `repos.tf`.
- **Excluded**: forks and the `test` repo.
