#!/usr/bin/env python3
import json
import subprocess
import os
import sys
from datetime import datetime

# Configuration
RULESET_NAME = "Secure Default Branch"
# The ruleset definition matches the one used in the bash script
RULESET_DEFINITION = {
    "name": RULESET_NAME,
    "target": "branch",
    "enforcement": "active",
    "conditions": {
        "ref_name": {
            "include": ["~DEFAULT_BRANCH"],
            "exclude": []
        }
    },
    "rules": [
        {"type": "required_signatures"},
        {"type": "deletion"},
        {"type": "non_fast_forward"}
    ]
}

def run_command(command):
    """Run a shell command and return output."""
    try:
        result = subprocess.run(
            command, shell=True, check=True, capture_output=True, text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {command}\n{e.stderr}", file=sys.stderr)
        return None

def get_repos():
    """Fetch all non-archived repositories."""
    print("Fetching repositories...")
    # Fetch list of repos (limit 1000)
    cmd = "gh repo list --no-archived --json nameWithOwner,defaultBranchRef --limit 1000"
    output = run_command(cmd)
    if output:
        return json.loads(output)
    return []

def apply_ruleset(repo_name):
    """Apply the ruleset to a repository."""
    print(f"  Attempting to apply ruleset to {repo_name}...")
    # Convert definition to JSON string
    input_json = json.dumps(RULESET_DEFINITION)
    
    # We use 'gh api' to POST the ruleset.
    # Note: If a ruleset with the same name exists, it might create a duplicate or fail depending on API.
    # A more robust approach would be to list rulesets first, find ID, and UPDATE.
    # For simplicity in this v1, we try to create. 
    # If it fails (e.g., already exists), we might capture that, but the goal is enforcement.
    
    # Check if exists first?
    # List rulesets
    check_cmd = f"gh api repos/{repo_name}/rulesets --jq '.[] | select(.name == \"{RULESET_NAME}\") | .id'"
    existing_id = run_command(check_cmd)
    
    if existing_id:
        print(f"  Ruleset '{RULESET_NAME}' exists (ID: {existing_id}). Updating...")
        cmd = f"echo '{input_json}' | gh api repos/{repo_name}/rulesets/{existing_id} --method PUT --input -"
    else:
        print(f"  Creating new ruleset '{RULESET_NAME}'...")
        cmd = f"echo '{input_json}' | gh api repos/{repo_name}/rulesets --method POST --input -"
        
    result = run_command(cmd)
    return result is not None

def audit_and_enforce():
    repos = get_repos()
    report = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "total_repos": len(repos),
        "compliant_repos": 0,
        "enforced_repos": 0,
        "failed_repos": 0,
        "details": []
    }

    for repo in repos:
        name = repo['nameWithOwner']
        print(f"Checking {name}...")
        
        # In a real "audit", we would checking if the ruleset is active.
        # Here we follow the "Enforce" philosophy: Just try to apply/update it.
        # Use success/failure of utility as compliance metric.
        
        success = apply_ruleset(name)
        
        status = "COMPLIANT" if success else "FAILED"
        if success:
            report["compliant_repos"] += 1
            report["enforced_repos"] += 1
        else:
            report["failed_repos"] += 1
            
        report["details"].append({
            "repo": name,
            "status": status,
            "default_branch": repo.get("defaultBranchRef", {}).get("name", "unknown")
        })

    # Output report to file
    with open("policy-report.json", "w") as f:
        json.dump(report, f, indent=2)
    
    print(f"\nAudit Complete. Compliant: {report['compliant_repos']}/{report['total_repos']}")
    print("Report saved to policy-report.json")

if __name__ == "__main__":
    if not os.environ.get("GITHUB_TOKEN"):
        print("Error: GITHUB_TOKEN environment variable is not set.", file=sys.stderr)
        sys.exit(1)
        
    audit_and_enforce()
