# Remote state in Cloudflare R2 (S3-compatible). Keeping state shared means CI
# drift detection is exact — no per-run "to import" noise. The bucket is
# provisioned by the nix/terraform Cloudflare config (kleinbem-tofu-state).
#
# Account-specific endpoint + R2 credentials are supplied at init time, NOT
# committed:
#   - endpoint  -> -backend-config (generated from $CLOUDFLARE_ACCOUNT_ID; see Justfile)
#   - creds     -> AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env (R2 access key)
terraform {
  backend "s3" {
    bucket = "kleinbem-tofu-state"
    key    = "github-config.tfstate"
    region = "auto"

    # R2 is S3-compatible but not AWS — skip the AWS-specific probes.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true # native state locking via R2 conditional writes
  }
}
