# GitHub Governance & Configuration

Single source of truth for **all** owned `kleinbem` repos' GitHub config
(settings, rulesets, labels, security). This repo is **private**, so it safely
declares private repos too. The [`nix`](https://github.com/kleinbem/nix)
meta-repo's `terraform/` owns only the Actions **secret** distribution for its
CI repos (those values come from sops). Two halves here:

| Half | Tooling | What |
|---|---|---|
| **Enforcement** (drift-free) | Terraform (`*.tf`) | repo settings, default-branch rulesets, standard labels, secret scanning + Dependabot |
| **Observability** (read-only) | `scripts/govern.py` + weekly Action | `DASHBOARD.md`, traffic archive |

This replaces the earlier imperative Python+`gh` enforcement scripts (preserved
on the `archive/script-era-wip` branch).

## Enforcement (Terraform)

Repos and their settings are declared in `repos.tf`; resources in `github.tf`.
Existing repos are **adopted via `import` blocks** — the first apply normalises
settings, it never creates or destroys. **State lives in Cloudflare R2**
(bucket `kleinbem-tofu-state`, provisioned by the nix/terraform Cloudflare
config) so CI drift detection is exact.

### Setup (one-time)
1. Apply `nix/terraform` first so the R2 state bucket exists.
2. Create an **R2 API token** (Cloudflare → R2 → Manage API Tokens) → an access
   key id + secret.
3. Export the backend env (e.g. via direnv / your shell):
   ```bash
   export CLOUDFLARE_ACCOUNT_ID=...        # for the R2 S3 endpoint
   export AWS_ACCESS_KEY_ID=...            # R2 access key id
   export AWS_SECRET_ACCESS_KEY=...        # R2 secret
   ```
4. `nix develop` then `just migrate-state` (moves existing local state into R2).

### Day-to-day
```bash
just plan    # REVIEW: imports + in-place updates, zero destroy/create
just apply
```

The provider token comes from `gh auth token` (or a fine-grained PAT) and needs
Administration R/W (settings + rulesets), Issues R/W (labels), Metadata R across
the managed repos.

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
- **Note**: nix CI repos (`nix`, `nix-config`, `nix-packages`) have their
  *settings* here but their Actions *secrets* in `nix/terraform`.
