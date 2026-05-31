#!/usr/bin/env python3
"""Governance reporting for the kleinbem GitHub account.

Read-only observability — the *enforcement* (settings, rulesets, labels) is
declarative in Terraform now; this only reports. Replaces the old stats /
stale-branches / workflow-audit / community-health / ai-readiness / dashboard
scripts with one pass and shared helpers.

Usage:
    govern.py report     # write DASHBOARD.md (+ governance-report.json)
    govern.py traffic     # append today's views/clones to traffic_data/
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

OWNER = "kleinbem"
STALE_DAYS = 180
COMMUNITY_FILES = ["CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "CODEOWNERS", "SECURITY.md"]
AI_MARKERS = {".agent": "Antigravity", ".claude": "Claude", ".cursorrules": "Cursor", ".gemini": "Gemini"}
ROOT = Path(__file__).resolve().parent.parent


def gh(*args: str) -> str:
    """Run a gh command, return stdout ("" on failure — callers treat as empty)."""
    try:
        return subprocess.run(["gh", *args], check=True, capture_output=True, text=True).stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def gh_json(*args: str, default=None):
    out = gh(*args)
    if not out:
        return default
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return default


def repos() -> list[dict]:
    return gh_json("repo", "list", OWNER, "--no-archived", "--limit", "1000",
                   "--json", "name,nameWithOwner,visibility,description,defaultBranchRef", default=[]) or []


def stale_branch_count(full: str) -> int:
    cutoff = datetime.now(timezone.utc) - timedelta(days=STALE_DAYS)
    branches = gh_json("api", f"repos/{full}/branches", "--paginate", default=[]) or []
    n = 0
    for b in branches:
        if b["name"] in ("main", "master"):
            continue
        date = gh("api", f"repos/{full}/commits/{b['commit']['sha']}", "--jq", ".commit.committer.date")
        if date and datetime.fromisoformat(date.replace("Z", "+00:00")) < cutoff:
            n += 1
    return n


def workflow_counts(full: str) -> tuple[int, int]:
    wfs = (gh_json("api", f"repos/{full}/actions/workflows", default={}) or {}).get("workflows", [])
    active = sum(1 for w in wfs if w.get("state") == "active")
    return active, len(wfs) - active


def community_score(full: str) -> int:
    # gh() returns "" on a 404 (file absent) and the file JSON when present.
    found = sum(1 for f in COMMUNITY_FILES if gh("api", f"repos/{full}/contents/{f}"))
    return round(found / len(COMMUNITY_FILES) * 100)


def ai_tools(full: str) -> list[str]:
    root = gh_json("api", f"repos/{full}/contents", default=[]) or []
    names = {e["name"] for e in root if isinstance(e, dict)}
    return [label for marker, label in AI_MARKERS.items() if marker in names]


def report() -> None:
    rows = []
    for r in repos():
        full = r["nameWithOwner"]
        print(f"  scanning {full}...", file=sys.stderr)
        counts = gh_json("api", "graphql", "-f", (
            'query={repository(owner:"%s",name:"%s"){'
            'refs(refPrefix:"refs/heads/"){totalCount} issues(states:OPEN){totalCount}}}'
        ) % (OWNER, r["name"]), default={}) or {}
        repo = (counts.get("data") or {}).get("repository") or {}
        active, disabled = workflow_counts(full)
        rows.append({
            "repo": r["name"],
            "visibility": r["visibility"].lower(),
            "branches": (repo.get("refs") or {}).get("totalCount", 0),
            "open_issues": (repo.get("issues") or {}).get("totalCount", 0),
            "stale_branches": stale_branch_count(full),
            "workflows_active": active,
            "workflows_disabled": disabled,
            "community_score": community_score(full),
            "ai_tools": ai_tools(full),
            "has_description": bool(r.get("description")),
        })

    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    (ROOT / "governance-report.json").write_text(
        json.dumps({"generated": generated, "repos": rows}, indent=2) + "\n")

    lines = [
        "# Governance Dashboard", "",
        f"_Generated {generated} — read-only report; enforcement lives in Terraform._", "",
        "| Repo | Vis | Branches | Open issues | Stale | Workflows (✓/✗) | Community | AI |",
        "|---|---|--:|--:|--:|--|--:|--|",
    ]
    for x in sorted(rows, key=lambda r: r["repo"]):
        wf = f"{x['workflows_active']}/{x['workflows_disabled']}"
        ai = ", ".join(x["ai_tools"]) or "—"
        lines.append(
            f"| {x['repo']} | {x['visibility']} | {x['branches']} | {x['open_issues']} | "
            f"{x['stale_branches']} | {wf} | {x['community_score']}% | {ai} |")
    (ROOT / "DASHBOARD.md").write_text("\n".join(lines) + "\n")
    print(f"Wrote DASHBOARD.md ({len(rows)} repos).", file=sys.stderr)


def traffic() -> None:
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    out = {}
    for r in repos():
        full, name = r["nameWithOwner"], r["name"]
        views = gh_json("api", f"repos/{full}/traffic/views", default={}) or {}
        clones = gh_json("api", f"repos/{full}/traffic/clones", default={}) or {}
        if views or clones:
            out[name] = {
                "views": views.get("count", 0), "unique_views": views.get("uniques", 0),
                "clones": clones.get("count", 0), "unique_clones": clones.get("uniques", 0),
            }
    d = ROOT / "traffic_data"
    d.mkdir(exist_ok=True)
    (d / f"{day}.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"Wrote traffic_data/{day}.json ({len(out)} repos).", file=sys.stderr)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    {"report": report, "traffic": traffic}.get(cmd, lambda: sys.exit(f"unknown command: {cmd}"))()
