---
name: review
description: Review code changes before creating a PR. Runs quality checks and provides feedback.
---

## Local Code Review

Review the current changes and provide feedback:

### Step 1: Gather Changes
!`git diff --stat`
!`git diff --name-only`

### Step 2: Run Quality Checks
Run these checks and report results:

1. **RuboCop** (Ruby style):
   ```bash
   bin/rubocop --format simple
   ```

2. **HAML Lint** (template quality):
   ```bash
   bundle exec haml-lint app/views/
   ```

3. **Brakeman** (security):
   ```bash
   brakeman --no-pager --quiet
   ```

4. **Tests** (for changed files):
   Identify relevant test files and run them.

### Step 3: Code Review Checklist
Review the diff for:
- [ ] Security issues (SQL injection, XSS, command injection)
- [ ] N+1 query potential (missing `.includes()`)
- [ ] Missing error handling
- [ ] Code complexity (should anything be extracted?)
- [ ] Turbo Frame scope issues (all related UI in same frame?)

### Step 4: Summary
Provide:
- **Issues Found**: List with file:line references
- **Suggestions**: Optional improvements
- **Ready for PR**: Yes/No with explanation
