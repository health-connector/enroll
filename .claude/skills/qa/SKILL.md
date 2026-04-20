---
name: qa
description: Run or build QA test scenarios with Playwright MCP. Use `/qa <scenario>` to run or `/qa new <name>` to build a new scenario interactively.
---

> **FIRST:** Read `.claude/KNOWLEDGE.md` before starting. It has dev environment quirks, datepicker patterns, login field names, and seed docs.

---

## Mode Detection

| Input | Action |
|-------|--------|
| `new <name>` | **Builder** — guided walkthrough to create a scenario YAML |
| `<name>` | **Runner** — execute the named scenario |
| *(empty)* | **List** — show available scenarios |

Scenarios live in `.aidocs/scenarios/automated/` (skill-created) or `.aidocs/scenarios/` (user-authored).

---

## Runner Mode

### 1. Seed the Database

If the scenario has `setup.setup_script`, run it:
```bash
source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma && bundle exec rails runner .aidocs/seeds/<setup_script>
```

If `setup.prerequisites` is set, run each in order:
```bash
source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma
bundle exec rails runner .aidocs/seeds/employer_ready.rb
PROFILE_ID=<id> SPONSORSHIP_ID=<id> bundle exec rails runner .aidocs/seeds/plan_year_published.rb
PROFILE_ID=<id> PACKAGE_ID=<id> bundle exec rails runner .aidocs/seeds/census_employee_enrollable.rb
```

Available composable seeds in `.aidocs/seeds/`:

| Seed | ENV vars | What it creates |
|------|----------|-----------------|
| `employer_ready.rb` | — | Employer org, approved attestation, staff user |
| `plan_year_published.rb` | `PROFILE_ID`, `SPONSORSHIP_ID` | Plan year, benefit package, BGAs |
| `census_employee_enrollable.rb` | `PROFILE_ID`, `PACKAGE_ID` | Census employee + user account |

### 2. Login

Use `mcp_playwright_browser_run_code` to fill and submit the login form. The login field is `#user_login` (not `#user_email`):

```javascript
async (page) => {
  await page.fill('#user_login', 'email@example.com');
  await page.fill('#user_password', 'Password1!');
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle' }),
    page.click('input[type="submit"], button[type="submit"]')
  ]);
  return page.url();
}
```

### 3. Execute Steps — Reconnaissance-Then-Action

For every step:
1. `mcp_playwright_browser_snapshot()` — get current refs
2. `mcp_playwright_browser_take_screenshot(filename: "sNN_description.png")` — save **before** acting
3. Act — click, fill, navigate
4. Wait for next page content: `mcp_playwright_browser_wait_for(text: "Expected text")`
5. Verify snapshot matches assertions

> **Screenshot filenames** use `sNN_` prefix (e.g. `s01_login.png`, `s02_home.png`).
> Save to `.aidocs/screenshots/` using the full relative path: `filename: ".aidocs/screenshots/s01_login.png"`.

### 4. Publish to ClickUp — MANDATORY

Complete this after every run. Do not skip.

**Step 1 — Upload screenshots.** Run after all screenshots are captured:

> **NEVER inline the API token value in terminal commands.** Always reference it as `$CLICKUP_API_TOKEN`. If the variable is not set in the current shell, load it first with `source ~/.zshrc`.

```bash
source ~/.zshrc
mkdir -p .aidocs/screenshots
for f in .aidocs/screenshots/s0*.png; do
  name=$(basename "$f")
  URL=$(curl -s -X POST "https://api.clickup.com/api/v2/task/868jahba6/attachment" \
    -H "Authorization: $CLICKUP_API_TOKEN" \
    -F "attachment=@$(realpath $f);type=image/png" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['url'])")
  echo "$name -> $URL"
done
```
Upload **one file at a time** if the loop gets interrupted. CDN URL format: `https://t9011313074.p.clickup-attachments.com/t9011313074/<uuid>/filename.png`

**Step 2 — Create the ClickUp Doc:**
```
mcp_my-mcp-server_clickup_create_document(name: "QA Test Report: ...", parent: {id: "9011313074", type: "12"}, visibility: "PUBLIC", create_page: true)
mcp_my-mcp-server_clickup_list_document_pages(document_id: "<doc_id>")  # get page_id
```

**Step 3 — Update the page** with the full Markdown report (CDN image URLs embedded inline):
```
mcp_my-mcp-server_clickup_update_document_page(document_id, page_id, content: "<markdown>", content_format: "text/md")
```

**Step 4 — Clean up:**
```bash
rm -f .aidocs/screenshots/*.png
rm -f .playwright-mcp/*.png .playwright-mcp/*.yml .playwright-mcp/*.log
```

### 5. Report Template

Build the Markdown in memory and pass directly to `update_document_page`. No local file needed.

```markdown
# QA Test Report: <Scenario Name>

| Field | Value |
|-------|-------|
| **Date** | YYYY-MM-DD |
| **Environment** | Local Development |
| **Branch** | `branch-name` |
| **Result** | ✅ PASS — N/N steps passed |

## Accounts
| Role | Email | Password |
|------|-------|----------|
| Employee | email@example.com | Password1! |

## Seed Data
```json
{ "profile_id": "...", "enrollment_id": "..." }
```

## Steps

### Step N — Name
**URL:** `/path`

| Field | Value |
|-------|-------|
| field label | exact value entered |

**IDs created:** ModelName → `<bson_id>`

![Step N](https://t9011313074.p.clickup-attachments.com/...)

## Issues Encountered
None. (or table of issues)

---
*QA Agent | YYYY-MM-DD | branch*
```

---

## Builder Mode (`/qa new <name>`)

1. Navigate to the target URL and take a snapshot
2. Show the user what's on the page (forms, buttons, key elements)
3. Ask what to test — build steps iteratively (action → expected result)
4. Write the scenario YAML to `.aidocs/scenarios/automated/<name>.yml`
5. Offer to run it immediately

### Scenario YAML Format

```yaml
scenario:
  name: "Human-readable name"
  setup:
    auth: employee_login          # admin_login | employer_login | employee_login | none
    prerequisites:
      - employer_ready
      - plan_year_published
      - census_employee_enrollable
  steps:
    - name: "Step name"
      url: "/path"                # navigate here first (optional)
      wait_for: "Expected text"
      screenshot: true
      actions:
        - click: "Button text"
        - type: { ref: "field_ref", text: "value" }
        - js: "document.querySelector('input[name=\"...\"]').value = '...'"
      assertions:
        - text_present: "Expected text"
        - text_absent: "Should not appear"
```

---

## Common URLs

| Portal | URL |
|--------|-----|
| HBX Admin | `/exchanges/hbx_profiles` |
| Employee | `/insured/families/home` |
| Employer registration | `/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor` |
| Broker registration | `/benefit_sponsors/profiles/registrations/new?portal=true&profile_type=broker_agency` |
