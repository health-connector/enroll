---
name: qa
description: Run or build QA test scenarios with Playwright MCP. Use `/qa <scenario>` to run or `/qa new <name>` to build a new scenario interactively.
---

You are the QA Testing Agent. You run scenario-driven browser tests and help build new scenarios.

$ARGUMENTS

> **BEFORE STARTING:** Read `.claude/KNOWLEDGE.md` — it contains dev environment quirks, known
> model gotchas, Playwright patterns, and seed script documentation for this codebase.
> Many issues (datepicker hidden fields, attestation, BGA assignments) are already solved there.

---

## Mode Detection

Parse `$ARGUMENTS` to determine the mode:

| Input | Mode | Action |
|-------|------|--------|
| `new <name>` | **Builder** | Guided walkthrough to create a new scenario YAML |
| `<name>` | **Runner** | Run the named scenario |
| *(empty)* | **List** | List all available scenarios |

Scenarios live in `.aidocs/scenarios/automated/` (skill-created) or `.aidocs/scenarios/` (user-authored).
Always search both locations when running a scenario by name.

---

## Runner Mode

### 1. Load Scenario
Search for the YAML in this order:
1. `.aidocs/scenarios/automated/<name>.yml` (skill-created)
2. `.aidocs/scenarios/<name>.yml` (user-authored)

### 2. Seed the Database

If `setup.setup_script` is set, run it:
```bash
source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma && bundle exec rails runner .aidocs/seeds/<setup_script>
```

If `setup.prerequisites` is set (scenario chaining), run each referenced seed in order:
```bash
for seed in <prerequisite_seeds>; do
  bundle exec rails runner .aidocs/seeds/${seed}.rb
done
```

Otherwise use the generic seeder:
```bash
SCENARIO_FILE=.aidocs/scenarios/automated/<name>.yml bundle exec rails runner db/seedfiles/cca/cca_seed.rb
```

#### Composable Seeds (`.aidocs/seeds/`)

For employer/enrollment flows, prefer composable seeds over ad-hoc DB manipulation:

| Seed | ENV vars required | What it sets up |
|---|---|---|
| `helpers.rb` | — | Shared utilities (auto-loaded by other seeds) |
| `employer_ready.rb` | — | Employer org, approved attestation, zip 01247, staff user |
| `plan_year_published.rb` | `PROFILE_ID`, `SPONSORSHIP_ID` | Published plan year + benefit package + BGAs |
| `census_employee_enrollable.rb` | `PROFILE_ID`, `PACKAGE_ID` | Enrollable census employee + employee account |

Full E2E chain (pass output IDs between seeds):
```bash
# Step 1: employer
bundle exec rails runner .aidocs/seeds/employer_ready.rb | tail -3
# Copy profile_id, sponsorship_id from output

# Step 2: plan year
PROFILE_ID=<id> SPONSORSHIP_ID=<id> bundle exec rails runner .aidocs/seeds/plan_year_published.rb | tail -3
# Copy package_id from output

# Step 3: census employee
PROFILE_ID=<id> PACKAGE_ID=<id> bundle exec rails runner .aidocs/seeds/census_employee_enrollable.rb | tail -3
```

If `setup.auth` is `none`, skip seeding (or seed only the record, no user).

### 4. Authenticate

| auth type | Method |
|-----------|--------|
| `admin_login` | Navigate to `/exchanges/hbx_profiles`, fill email/password from seeder output |
| `none` | Skip — page is public |

### 5. Execute Steps

For each step in the scenario, follow the **Reconnaissance-Then-Action** pattern:

```
1. WAIT       -> browser_wait_for(step.wait_for)
2. SNAPSHOT   -> browser_snapshot() to discover refs
3. SCREENSHOT -> browser_take_screenshot() if step.screenshot
4. ACT        -> Execute step.actions (click, type, tamper, etc.)
5. WAIT       -> Wait for next page/error
6. SNAPSHOT   -> browser_snapshot() to verify result
7. ASSERT     -> Check step.assertions against the snapshot
8. DOCUMENT   -> Record pass/fail
```

### 6. Report Results & ClickUp Publishing

Reports are built in **Markdown format** for ClickUp Docs. ClickUp Docs support
standard Markdown with some extensions. Design for what ClickUp renders well.

#### What ClickUp Docs support well
- Markdown tables — use for metadata, summaries, timelines
- `#`, `##`, `###` — section headings
- Bullet lists with `**bold**` — action/expected/actual per step
- Inline images (uploaded as attachments, referenced by URL)
- Callout blocks using `>` blockquotes
- `code` — inline code and fenced code blocks
- Checklists and task references

#### What does NOT work well
- Complex HTML (ClickUp strips most raw HTML)
- Custom CSS or inline styles
- Nested tables
- Image references that aren't uploaded attachment URLs

#### Report structure template

Build a `.md` file with this structure:

```markdown
# QA Test Report: Scenario Name

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Environment** | Local Development |
| **Branch** | `branch-name` |
| **Application** | description |

> **Result:** X/Y steps passed. Details below.

## Accounts

| Role | Email | Password | Notes |
|------|-------|----------|-------|
| (role) | email@example.com | password | how created |

## Seed Script Output

If seeds were run, paste the full JSON output here. These IDs let anyone re-inspect or reproduce the state.

```json
{
  "profile_id": "<bson_id>",
  "sponsorship_id": "<bson_id>",
  "application_id": "<bson_id>",
  "package_id": "<bson_id>",
  "census_employee_id": "<bson_id>"
}
```

## Steps

For **every step** that involves a form, action, or data creation — include:
1. The URL
2. A table of **every field and the exact value entered** (including hidden fields, pre-filled values, and any values set via JS)
3. Any MongoDB IDs created as a result
4. The screenshot

> **Rule:** If you typed it, selected it, clicked it, or set it via JS — it goes in the table.
> Do NOT summarise. Record the actual value.

### Step N — [Step Name]

**URL:** `/path/to/page`

| Field | DOM name (if non-obvious) | Value entered |
|-------|--------------------------|---------------|
| Field label | input[name="..."] | exact value |

**MongoDB IDs created:**

| Model | ID |
|-------|----|
| ModelName | \<bson_id\> |

**Notes:** any fixes applied, hidden fields set via JS, etc.

![Step N screenshot](cdn-url/sNN_description.png)

<!-- Repeat a Step block for every step -->

## Issues Encountered

| # | Issue | Input that triggered it | Fix applied |
|---|-------|------------------------|-------------|
| 1 | description | exact input / field | what was changed |

## Enrollment Timeline

| Time | Status |
|------|--------|
| HH:MM:SS | status_name |

## Documents
- [Download PDF](attachment-url-or-local-path/document.pdf)

---
*Generated by Enroll QA Testing Agent | date | branch*
```

Build this content in memory and write it directly to the ClickUp Doc page (step 5 of the publishing workflow). No local file needed.

#### Publishing workflow — MANDATORY after every test run

> **IMPORTANT:** This entire workflow MUST be completed after every test run.
> Do NOT finish a QA session without creating the ClickUp Doc.
> Follow these steps IN ORDER — do not skip any.

1. **Save screenshots** during the test run to `.playwright-mcp/` (Playwright MCP default).

2. **Build the report locally** — write the Markdown report to `.aidocs/reports/<scenario-name>.md`. Use placeholder image paths initially; replace with CDN URLs after upload.

3. **Upload screenshots via the ClickUp REST API** (not MCP) — do this BEFORE creating the Doc so you have all CDN URLs ready:
   - ClickUp attachment API requires a task ID — it cannot attach directly to a Doc.
   - Use the permanent QA screenshot host task: `868jahba6`
     (https://app.clickup.com/t/868jahba6 — created specifically for this purpose, do not delete)

   Upload each screenshot to the permanent host task:
   ```bash
   source ~/.zshrc
   URL=$(curl -s -X POST "https://api.clickup.com/api/v2/task/868jahba6/attachment" \
     -H "Authorization: $CLICKUP_API_TOKEN" \
     -F "attachment=@/absolute/path/to/screenshot.png;type=image/png" \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['url'])")
   echo "$URL"
   ```

   Loop over all screenshots:
   ```bash
   source ~/.zshrc
   for f in .playwright-mcp/*.png; do
     URL=$(curl -s -X POST "https://api.clickup.com/api/v2/task/868jahba6/attachment" \
       -H "Authorization: $CLICKUP_API_TOKEN" \
       -F "attachment=@$(realpath $f);type=image/png" \
       | python3 -c "import json,sys; print(json.load(sys.stdin)['url'])")
     echo "$f -> $URL"
   done
   ```
   URL format: `https://t9011313074.p.clickup-attachments.com/t9011313074/<uuid>/filename.png`

   Collect ALL CDN URLs before proceeding to the next step.

4. **Create a ClickUp Doc and page** via MCP:
   - Use `mcp_my-mcp-server_clickup_create_document` to create the doc.
   - Use `mcp_my-mcp-server_clickup_list_document_pages` to get the auto-created page ID.
   - Workspace: `9011313074`

5. **Update the Doc page** with inline images using CDN URLs:
   - Use `mcp_my-mcp-server_clickup_update_document_page` with `content_format: "text/md"`.
   - Embed images as: `![description](https://t9011313074.p.clickup-attachments.com/...)`
   - ClickUp renders these inline in Docs natively.

6. **Clean up** — run immediately after the Doc is updated:
   - Delete all Playwright MCP temp files AND the local report:
     ```bash
     rm -f .playwright-mcp/*.png .playwright-mcp/*.yml .playwright-mcp/*.log
     rm -f .aidocs/reports/<scenario-name>.md
     ```
   - **Do not commit screenshots or reports** — the ClickUp Doc is the only record.

#### ClickUp credentials
The API token is stored in `~/.zshrc`:
```bash
export CLICKUP_API_TOKEN="..."
```
Always run `source ~/.zshrc` before using `curl` commands.
---

## Builder Mode (`/qa new`)

When `$ARGUMENTS` starts with `new`, enter the guided scenario builder.

### Builder Workflow

1. **Parse the target**: Extract `<name>` from args. If missing, ask.

2. **Ask for the URL**: "What page/URL do you want to test?" (or infer from the name)

3. **Determine auth**: "Does this page need admin login, student login (magic link), or no auth?"

4. **Navigate and snapshot**: Open the page in Playwright, take a snapshot and screenshot.

5. **Present what you see**: Show the user the key interactive elements found:
   - Forms and their fields
   - Buttons and links
   - Filters and search inputs
   - Tabs and navigation

6. **Ask about DB state**: "What data needs to exist for this page?" Suggest factories by searching `spec/factories/` for matching models. Show relevant factory traits.

7. **Build steps iteratively**: For each test step:
   - Ask: "What should we test next?" (or suggest based on what's on the page)
   - Ask: "What action?" (click, fill, tamper, etc.)
   - Ask: "What should we expect after?" (text appears, page changes, error shown)
   - Add the step to the draft YAML

8. **Write the YAML**: Save to `.aidocs/scenarios/automated/<name>.yml`

9. **Offer to run it**: "Scenario saved. Want me to run it now?"

### Builder Helpers

- `browser_snapshot()` to discover page elements and refs
- `Grep` on `spec/factories/` to find relevant factories
- `Grep` on `config/routes.rb` to understand URL structure
- `Read` on the controller to understand required DB state

---

## Scenario YAML Format

```yaml
scenario:
  name: "Human-readable name"
  description: "What this scenario tests"
  tags: [happy_path]             # Freeform tags for documentation

  setup:
    auth: admin_login               # admin_login | employer_login | employee_login | none
    setup_script: qa_seed_<name>.rb # Single seed script in .aidocs/seeds/ (optional)
    prerequisites:                  # Chained seeds — run in order before this scenario
      - employer_ready              # .aidocs/seeds/employer_ready.rb
      - plan_year_published         # .aidocs/seeds/plan_year_published.rb
      - census_employee_enrollable  # .aidocs/seeds/census_employee_enrollable.rb
    seed_env:                       # ENV vars passed to each seed
      QA_ORG_NAME: "Test Corp"
      QA_EMPLOYER_EMAIL: "employer@example.com"

  steps:
    - name: "Step name"
      url: "/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor"   # Optional: navigate to URL
      wait_for: "Expected text"       # Wait for this text before acting
      screenshot: true                # Take screenshot at this step
      actions:                        # Actions to perform
        - click: "Button text"
        - type: { ref: "field_ref", text: "value" }
        - select: { ref: "select_ref", value: "option" }
        - tamper: { selector: "css_selector", value: "new_value" }
        - js: "document.querySelector('input[name=...]').value = '...'"  # JS eval for hidden fields
      assertions:                     # Verify after actions
        - text_present: "Expected text"
        - text_absent: "Should not see"
```

---

## Quick Reference

### Common URLs
- Local dev: `http://localhost:3000`
- HBX Portal: `/exchanges/hbx_profiles`
- Employee Portal: `/insured/employee/privacy`
- Employer Portal: `/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor`
- Broker Agency Portal: `/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=broker_agency`
- Broker Registration: `/benefit_sponsors/profiles/registrations/new?profile_type=broker_agency`

### Scenario Location
- Your own scenarios: `.aidocs/scenarios/`
- Skill-generated scenarios: `.aidocs/scenarios/automated/`

---

## Playwright Patterns Cookbook

Copy-paste snippets for Enroll-specific browser interactions. Full patterns also in `.claude/KNOWLEDGE.md`.

### jQuery datepicker — set both visible and hidden fields
```javascript
// page.evaluate() — adjust selectors per form
document.querySelector('input#census_employee_dob').value = '01/15/1990';
document.querySelector('input[name="census_employee[dob]"]').value = '1990-01-15';
document.querySelector('input#census_employee_hired_on').value = '01/01/2026';
document.querySelector('input[name="census_employee[hired_on]"]').value = '2026-01-01';
```

### Employee signup — set email AND oim_id
```javascript
// page.evaluate()
document.querySelector('input[name="user[email]"]').value = 'john@example.com';
document.querySelector('input[name="user[oim_id]"]').value = 'john@example.com';
document.querySelector('input[name="user[password]"]').value = 'Password1!';
document.querySelector('input[name="user[password_confirmation]"]').value = 'Password1!';
```

### Tamper a hidden field (generic)
Use the YAML `js` action type:
```yaml
actions:
  - js: "document.querySelector('input[name=\"census_employee[dob]\"]').value = '1990-01-15'"
```

### Wait for Turbolinks/Turbo Frame update
Always call `browser_wait_for("next page text")` after submit/click. Never assert immediately.

---

## Known Dev Environment Issues

> All known issues are documented with full code solutions in `.claude/KNOWLEDGE.md`.
> Consult that file first for any dev environment problem.

| Issue | Quick fix |
|-------|----------|
| SymmetricEncryption cipher errors on form submit | Use `rails runner` to test; seeded SSN/DOB uses old cipher |
| RVM gemset override | Prefix: `source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma` |
| jQuery datepicker hidden fields | Set both visible + hidden inputs via JS — see KNOWLEDGE.md |
| Employer attestation `unsubmitted` | Approve via `QASeed.approve_attestation!(profile)` or `employer_ready.rb` seed |
| Seeded employees missing BGAs | Run `QASeed.assign_benefit_package!(profile, package)` or use `plan_year_published.rb` |
| Employee signup `user[oim_id]` blank | Set both `oim_id` AND `email` fields via JS — see KNOWLEDGE.md |
| New hire eligibility blocked | Backdate `created_at`: `QASeed.backdate_census_employee!(ce)` or use `census_employee_enrollable.rb` |
| Rating area blank | Use zip `01247` (Berkshire, MA) — confirmed valid in dev |

---

## Remember
1. **Use `localhost:3000`** for all URLs in Playwright
2. **Seed fresh users per test** — form state prevents going backward
3. **Snapshot before acting** — get refs from current page state
4. **Wait after interactions** — Turbolinks needs time
5. **Reports** are published to ClickUp Docs and cleaned up locally — nothing to commit after the run
6. **ALWAYS create the ClickUp Doc** — after the test run, follow the full Publishing workflow (section above): upload screenshots, create ClickUp Doc, update page with CDN URLs, and clean up. This is NOT optional.
7. **Clean up `.playwright-mcp/`** — delete ALL files (`*.png`, `*.yml`, `*.log`) after uploading screenshots. These are temp artifacts, not to be committed.
8. **jQuery datepickers** — always set BOTH the visible display field AND the hidden value field via JavaScript. Using Playwright `fill()` alone will not work.
9. **Employer flows** — check attestation status, rating area, and benefit_group_assignments on seeded employees before attempting to publish a plan year.
