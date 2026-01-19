#!/usr/bin/env python3
import json
import subprocess
import os
import sys
import csv
from datetime import datetime

DATA_DIR = "traffic_data"

def run_command(command):
    try:
        result = subprocess.run(
            command, shell=True, check=True, capture_output=True, text=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

def get_repos():
    # Only public repos generally have full traffic data on Free plans,
    # but Private repos have it if you are owner. Fetch all.
    cmd = "gh repo list --no-archived --json nameWithOwner --limit 1000"
    output = run_command(cmd)
    if output:
        return json.loads(output)
    return []

def get_traffic(repo, metric):
    # metric: 'views' or 'clones'
    cmd = f"gh api repos/{repo}/traffic/{metric}"
    output = run_command(cmd)
    if output:
        return json.loads(output)
    return None

def ensure_data_dir():
    if not os.path.exists(DATA_DIR):
        os.makedirs(DATA_DIR)

def update_csv(repo_name, metric, data):
    # Metric data usually has 'count', 'uniques', 'timestamp'
    filename = os.path.join(DATA_DIR, f"{metric}.csv")
    file_exists = os.path.exists(filename)
    
    # Flatten data: Include Repo Name
    rows = []
    # The API returns 'views' or 'clones' list
    items = data.get(metric, [])
    
    for item in items:
        # Normalize timestamp to YYYY-MM-DD
        ts = item['timestamp'][:10]
        rows.append({
            "date": ts,
            "repo": repo_name,
            "count": item['count'],
            "uniques": item['uniques']
        })
        
    if not rows:
        return

    # Check for duplicates? 
    # The API returns last 14 days. We simply append.
    # To avoid duplicates, we could read existing file.
    # For a simple collector, appending and unique-ing later (in Grafana) is easier,
    # but let's do a quick de-dupe in memory if file isn't huge.
    
    existing = set()
    if file_exists:
        with open(filename, "r") as f:
            reader = csv.DictReader(f)
            for r in reader:
                existing.add((r['date'], r['repo']))
    
    mode = "a" if file_exists else "w"
    with open(filename, mode, newline='') as f:
        writer = csv.DictWriter(f, fieldnames=["date", "repo", "count", "uniques"])
        if not file_exists:
            writer.writeheader()
        
        for r in rows:
            if (r['date'], r['repo']) not in existing:
                writer.writerow(r)
                print(f"  Recorded {metric} for {repo_name} on {r['date']}")

def main():
    if not os.environ.get("GITHUB_TOKEN"):
        print("Error: GITHUB_TOKEN environment variable is not set.", file=sys.stderr)
        sys.exit(1)
        
    ensure_data_dir()
    repos = get_repos()
    
    for r in repos:
        name = r['nameWithOwner']
        print(f"Processing {name}...")
        
        views = get_traffic(name, "views")
        if views:
            update_csv(name, "views", views)
            
        clones = get_traffic(name, "clones")
        if clones:
            update_csv(name, "clones", clones)

if __name__ == "__main__":
    main()
