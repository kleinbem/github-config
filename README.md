# GitHub Governance & Configuration

Single source of truth for **all** owned `kleinbem` repos' GitHub config
(settings, rulesets, labels, security), private repos included. It holds no
secrets: state lives in R2, credentials in Actions secrets. The [`nix`](https://github.com/kleinbem/nix)
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

### Day-to-day (GitOps)
We use a full **Enterprise GitOps** pipeline to manage infrastructure safely:

1. **Plan:** Open a Pull Request. GitHub Actions will automatically run `tofu plan` and comment the exact drift detection results on the PR.
2. **Apply:** Once approved, merge the PR into `main`. GitHub Actions will seamlessly authenticate and run `tofu apply -auto-approve` in the cloud.

You no longer need to execute `just apply` locally!

*(Note: CI authenticates as a GitHub App via `app_auth {}` — the `APP_ID`/`APP_PRIVATE_KEY` Actions secrets, not a PAT. See `main.tf`'s provider block.)*

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
