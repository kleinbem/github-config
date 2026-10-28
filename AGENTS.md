# github-config

Single source of truth for every owned `kleinbem` repo's GitHub settings,
branch-protection rulesets, standard labels, and security config (secret
scanning + Dependabot). Public repo: it holds no secrets (state in R2,
credentials in Actions secrets), only repo names and settings.

## Layout

| Path | What lives here |
|---|---|
| `repos.tf` | Declares every managed repo + its settings. |
| `github.tf` | Rulesets, labels, and other shared resources. |
| `backend.tf` | Cloudflare R2 Terraform state backend. |
| `variables.tf` | Provider auth + shared variables. |
| `scripts/govern.py` | Read-only observability — regenerates `DASHBOARD.md` + `governance-report.json`. |

## Conventions

- **GitOps, not local apply**: open a PR, let CI (`terraform-plan.yaml`) comment drift; merging to `main` triggers `terraform-apply.yaml`. `just apply` locally is the exception, not the norm.
- **Auth is GitHub App `app_auth {}`** (`APP_ID`/`APP_PRIVATE_KEY` secrets) — not a PAT. Local and CI use the same mechanism (see `main.tf`'s provider block).
- Existing repos are **adopted via `import` blocks**, never created out-of-band — see the root CLAUDE.md's IaC placement rule (self-contained IaC gets its own repo; this is the canonical example).
- Never delete an IaC-managed resource via `gh repo delete` or the raw API — remove it from Terraform config and apply, or the state orphans and CI breaks on the next run.
- `just report` regenerates `DASHBOARD.md`; it's observability only, never hand-edited.
