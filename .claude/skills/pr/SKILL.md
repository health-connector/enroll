---
name: pr
description: Commit changes, push to feature branch, and create PR with ClickUp ticket integration. Runs all quality checks first.
---

## Commit, Push, and Create PR

> **Codebase knowledge:** Consult `.claude/KNOWLEDGE.md` for conventions, known model behaviors,
> and environment-specific facts before reviewing or describing changes.

### Configuration

- **ClickUp Base URL:** `https://app.clickup.com/t/`

### CRITICAL: Branch Safety Check
!`git branch --show-current`

**STOP IMMEDIATELY** if on `main` or `develop` branch. Create a feature branch first:
```bash
git checkout -b feature/descriptive-name
```

### Step 0: Detect ClickUp Task

Detect the ClickUp task ID using the following priority order.

1. **Skill arguments** — Check if `$ARGUMENTS` contains a ClickUp task ID (alphanumeric, e.g., `86abcdef0`). If found, extract it.

2. **Branch name** — Extract from the current branch name. Common patterns:
   - `feature/86abcdef0-some-description`
   - `fix/task-id-description`

3. **Commit history** — Scan recent commits for the task ID:
   ```bash
   git log develop..HEAD --oneline
   ```

4. **Prompt user** — If no task was detected in any of the above, use `AskUserQuestion` to ask:
   > "What is the ClickUp task URL or ID? (e.g., https://app.clickup.com/t/86abcdef0, or 'none')"

If the user responds with "none" (or similar), proceed without a task. Otherwise, extract the task ID.

Store the detected task (or lack thereof) for use in later steps.

### Step 1: Pre-flight Checks (MANDATORY)

Run ALL quality checks before proceeding. **Do not skip any.**

```bash
# RuboCop - Ruby style
bin/rubocop

# HAML Lint - Template quality
bundle exec haml-lint app/views/

# Brakeman - Security analysis
brakeman --no-pager --quiet
```

For tests, identify and run relevant specs:
```bash
# Find test files for changed files
git diff --name-only | grep -E '\.(rb|haml)$' | while read f; do
  test_file=$(echo "$f" | sed 's|app/|spec/|' | sed 's|\.rb$|_spec.rb|' | sed 's|\.haml$|_spec.rb|')
  [ -f "$test_file" ] && echo "$test_file"
done | sort -u
```

**STOP if any check fails.** Fix issues first, then re-run this skill.

### Step 2: Review Changes

!`git status`
!`git diff --stat`

### Step 3: Commit

Stage and commit. The commit message should be a clear description of the changes:

- If `$ARGUMENTS` contains a description, use it as the commit message.
- If no `$ARGUMENTS` were provided, generate a descriptive commit message from the changes.

```bash
git add -A
git commit -m "<descriptive message>

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 4: Push to Origin

```bash
git push -u origin $(git branch --show-current)
```

### Step 5: Create Pull Request

Always use explicit `--title` and `--body` format with `gh pr create`. Incorporate the ClickUp task into the PR.

**PR Title:** Brief description of changes

**PR Body format (with ClickUp task):**
```
## ClickUp Task
https://app.clickup.com/t/<task-id>

## Summary
- Change 1
- Change 2

## Test Plan
- [ ] Verified X
- [ ] Tested Y
```

**PR Body format (without task):**
```
## Summary
- Change 1
- Change 2

## Test Plan
- [ ] Verified X
- [ ] Tested Y
```

Create the PR targeting `develop`:
```bash
gh pr create --base develop --title "Brief description" --body "$(cat <<'EOF'
## ClickUp Task
https://app.clickup.com/t/<task-id>

## Summary
- Change 1
- Change 2

## Test Plan
- [ ] Verified X
- [ ] Tested Y
EOF
)"
```

### Step 6: Add Screenshots to PR (If Relevant)

If the changes include **visual/UI modifications** (views, CSS, components, layout changes), add screenshots to the PR as a comment:

1. **Take screenshots** using Playwright MCP (`browser_take_screenshot`) showing the feature on desktop and mobile
2. **Commit screenshots** to the feature branch:
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   BRANCH=$(git branch --show-current)
   mkdir -p aidocs/screenshots/<feature-name>  # e.g., new-dashboard, modal-redesign
   cp .playwright-mcp/<screenshot>.png aidocs/screenshots/<feature-name>/01-descriptive-name.png
   git add aidocs/screenshots/
   git commit -m "docs: Add <feature-name> visual testing screenshots

   Co-Authored-By: Claude <noreply@anthropic.com>"
   git push origin $(git branch --show-current)
   ```
3. **Post PR comment** with embedded images using GitHub raw blob URLs.
   **IMPORTANT:** Use the commit SHA, not the branch name, in image URLs. Feature branches are deleted after merge, which breaks branch-based URLs permanently.
   ```bash
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   SHA=$(git rev-parse HEAD)
   gh pr comment <PR_NUMBER> --body "## Visual Testing Results

   ### Desktop
   ![Desktop view](https://github.com/${REPO}/blob/${SHA}/aidocs/screenshots/<feature-name>/01-desktop.png?raw=true)
   ✅ What was verified

   ### Mobile
   ![Mobile view](https://github.com/${REPO}/blob/${SHA}/aidocs/screenshots/<feature-name>/02-mobile.png?raw=true)
   ✅ What was verified"
   ```

**When to add screenshots:**
- Views, CSS, components, layout changes — yes
- Models, services, config, migrations — no
- Controllers — only if the template/UI changed

**Key details:**
- **Always use commit SHA** (not branch name) in image URLs — branches get deleted after merge
- Use `?raw=true` on GitHub blob URLs to embed images in markdown
- Use numeric prefixes (01-, 02-) for sort order in GitHub file browser
- Use descriptive filenames (01-desktop-view.png, not screenshot1.png)

### Step 7: Report Results

Provide the following:

1. **PR URL** — the link to the newly created pull request
2. **ClickUp Task** — if a task was detected, include: `ClickUp: https://app.clickup.com/t/<task-id>`
3. **Summary** — brief description of what was committed

If no task was detected, omit the ClickUp link from the output.
