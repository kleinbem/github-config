default:
    @just --list

# --- Enforcement (declarative, Terraform; state in Cloudflare R2) ----------

# Init the R2 backend. Requires env:
#   CLOUDFLARE_ACCOUNT_ID         — for the R2 S3 endpoint
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY — an R2 access key (token)
init:
    @test -n "${CLOUDFLARE_ACCOUNT_ID:-}" || { echo "set CLOUDFLARE_ACCOUNT_ID"; exit 1; }
    @printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    tofu init -input=false -backend-config=.r2-endpoint.hcl

# Review planned GitHub config changes (imports + in-place updates only).
plan: init
    TF_VAR_github_tf_token="$(gh auth token)" tofu plan

# Apply the GitHub config (settings, rulesets, labels).
apply: init
    TF_VAR_github_tf_token="$(gh auth token)" tofu apply

# One-time: migrate the existing local state into R2.
migrate-state:
    @test -n "${CLOUDFLARE_ACCOUNT_ID:-}" || { echo "set CLOUDFLARE_ACCOUNT_ID"; exit 1; }
    @printf 'endpoints = { s3 = "https://%s.r2.cloudflarestorage.com" }\n' "$CLOUDFLARE_ACCOUNT_ID" > .r2-endpoint.hcl
    tofu init -migrate-state -backend-config=.r2-endpoint.hcl

# --- Observability (read-only reporting) -----------------------------------

# Regenerate DASHBOARD.md + governance-report.json.
report:
    python3 scripts/govern.py report

# Append today's traffic stats to traffic_data/.
traffic:
    python3 scripts/govern.py traffic
