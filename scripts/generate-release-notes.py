#!/usr/bin/env python3
"""
katusaOS Release Notes Generator
Generates GitHub-compatible release notes between two Git tags.
"""

import argparse
import os
import re
import subprocess
import sys


def run_cmd(cmd):
    """Run a shell command and return stdout."""
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if res.returncode != 0:
        return ""
    return res.stdout.strip()


def get_repo_url():
    """Detect GitHub repository HTTPS URL from git remote."""
    remote = run_cmd("git remote get-url origin")
    if not remote:
        return "https://github.com/k-atusa/katusaOS"

    # git@github.com:k-atusa/katusaOS.git -> https://github.com/k-atusa/katusaOS
    if remote.startswith("git@github.com:"):
        path = remote.replace("git@github.com:", "").rstrip(".git")
        return f"https://github.com/{path}"
    elif remote.startswith("https://github.com/"):
        return remote.rstrip(".git")

    return "https://github.com/k-atusa/katusaOS"


def get_previous_tag(current_tag):
    """Find the tag immediately preceding current_tag in history."""
    if not current_tag:
        return None

    # Try git describe first
    prev = run_cmd(f"git describe --tags --abbrev=0 {current_tag}^ 2>/dev/null")
    if prev and prev != current_tag:
        return prev

    # Fallback to tag list ordered by creation date
    all_tags = run_cmd("git tag --sort=-creatordate").splitlines()
    all_tags = [t.strip() for t in all_tags if t.strip()]
    if current_tag in all_tags:
        idx = all_tags.index(current_tag)
        if idx + 1 < len(all_tags):
            return all_tags[idx + 1]

    # If current_tag wasn't found in list, pick the latest existing tag
    if all_tags:
        for t in all_tags:
            if t != current_tag:
                return t

    return None


def generate_changelog(current_tag, prev_tag=None, repo_url=None):
    """Generate Markdown release notes."""
    if not repo_url:
        repo_url = get_repo_url()

    if not prev_tag:
        prev_tag = get_previous_tag(current_tag)

    target_ref = current_tag
    if not run_cmd(f"git rev-parse -q --verify '{current_tag}'"):
        target_ref = "HEAD"

    if prev_tag:
        git_range = f"{prev_tag}..{target_ref}"
    else:
        git_range = target_ref

    raw_log = run_cmd(f'git log --reverse --format="%H|%h|%s" {git_range}')
    lines = ["## What's Changed"]

    for entry in raw_log.splitlines():
        if not entry.strip():
            continue
        parts = entry.split("|", 2)
        if len(parts) < 3:
            continue
        full_hash, short_hash, subject = parts[0], parts[1], parts[2]

        # Filter out noisy branch merge commits and release tag commits
        if re.match(r"^(Merge (branch|pull request) |chore\(release\): )", subject):
            continue

        commit_url = f"{repo_url}/commit/{full_hash}"
        lines.append(f"* {subject} ([{short_hash}]({commit_url}))")

    if prev_tag:
        lines.append(f"\n**Full Changelog**: {repo_url}/compare/{prev_tag}...{current_tag}")
    else:
        lines.append(f"\n**Full Changelog**: {repo_url}/commits/{current_tag}")

    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description="Generate katusaOS release notes")
    parser.add_argument("--tag", help="Current release tag (default: latest git tag or HEAD)")
    parser.add_argument("--prev-tag", help="Previous tag to compare against (default: auto-detect)")
    parser.add_argument("--repo-url", help="GitHub repo URL")
    parser.add_argument("--output", "-o", help="Output file path (default: stdout)")
    args = parser.parse_args()

    current_tag = args.tag
    if not current_tag:
        current_tag = run_cmd("git describe --tags --exact-match 2>/dev/null") or run_cmd("git tag --sort=-creatordate | head -n 1") or "HEAD"

    changelog = generate_changelog(current_tag, args.prev_tag, args.repo_url)

    if args.output:
        with open(args.output, "w") as f:
            f.write(changelog)
        print(f"[✓] Release notes written to {args.output}")
    else:
        print(changelog, end="")


if __name__ == "__main__":
    main()
