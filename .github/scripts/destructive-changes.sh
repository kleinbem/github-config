#!/usr/bin/env bash
# Usage: destructive-changes.sh PLANFILE
# Prints one line per deleted or replaced resource and per label a
# github_issue_labels set removes (an in-place update that deletes the label).
# Addresses and label names only: the plan JSON carries attribute values.
set -euo pipefail
tofu show -json "$1" | jq -r '
  def labels($x): [($x // {}) | .label[]? | .name];
  .resource_changes[]?
  | if (.change.actions | index("delete")) then
      "\(.change.actions | join("+"))  \(.address)"
    elif .type == "github_issue_labels" then
      (labels(.change.before) - labels(.change.after)) as $gone
      | select($gone | length > 0)
      | "remove labels \($gone | join(", "))  \(.address)"
    else empty end'
