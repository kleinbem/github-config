default:
    @just --list

# --- Enforcement (declarative, Terraform) ---------------------------------

# Review the planned GitHub config changes (imports + in-place updates only).
plan:
    TF_VAR_github_tf_token="$(gh auth token)" tofu plan

# Apply the GitHub config (settings, rulesets, labels).
apply:
    TF_VAR_github_tf_token="$(gh auth token)" tofu apply

# --- Observability (read-only reporting) ----------------------------------

# Regenerate DASHBOARD.md + governance-report.json.
report:
    python3 scripts/govern.py report

# Append today's traffic stats to traffic_data/.
traffic:
    python3 scripts/govern.py traffic
