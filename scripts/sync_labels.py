#!/usr/bin/env python3
import yaml
import json
import subprocess
import os
import sys

LABELS_FILE = "labels.yaml"

def run_command(command):
    try:
        result = subprocess.run(
            command, shell=True, check=True, capture_output=True, text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        # Ignore errors if label exists (POST fails) or label missing (DELETE fails)
        # We print but don't crash
        # print(f"Command failed: {command}\n{e.stderr}", file=sys.stderr)
        return None

def get_repos():
    cmd = "gh repo list --no-archived --json nameWithOwner --limit 1000"
    output = run_command(cmd)
    if output:
        return json.loads(output)
    return []

def get_current_labels(repo):
    cmd = f"gh label list --repo {repo} --limit 100 --json name,color,description"
    output = run_command(cmd)
    if output:
        return {l['name']: l for l in json.loads(output)}
    return {}

def load_standard_labels():
    with open(LABELS_FILE, "r") as f:
        return yaml.safe_load(f)

def sync_repo(repo, standard_labels):
    print(f"Syncing {repo}...")
    current = get_current_labels(repo)
    
    for std in standard_labels:
        name = std['name']
        color = std['color']
        desc = std['description']
        
        if name in current:
            # Update if changed
            curr = current[name]
            if curr['color'] != color or curr['description'] != desc:
                print(f"  Updating {name}")
                run_command(f"gh label edit \"{name}\" --repo {repo} --color \"{color}\" --description \"{desc}\"")
        else:
            # Create
            print(f"  Creating {name}")
            run_command(f"gh label create \"{name}\" --repo {repo} --color \"{color}\" --description \"{desc}\"")

def main():
    if not os.path.exists(LABELS_FILE):
        print(f"Error: {LABELS_FILE} not found.")
        sys.exit(1)
        
    standard_labels = load_standard_labels()
    repos = get_repos()
    
    for r in repos:
        sync_repo(r['nameWithOwner'], standard_labels)

if __name__ == "__main__":
    if not os.environ.get("GITHUB_TOKEN"):
        print("Error: GITHUB_TOKEN environment variable is not set.", file=sys.stderr)
        sys.exit(1)
    main()
