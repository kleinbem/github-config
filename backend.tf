# Shared state in Cloudflare R2; the bucket comes from nix/infra (main.tf).
# Not committed: the endpoint (-backend-config built from $CLOUDFLARE_ACCOUNT_ID
# by the Justfile) and the R2 credentials (AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY).
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
