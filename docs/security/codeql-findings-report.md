# CodeQL Security Findings Report

**Generated:** 2026-04-14
**Branch scanned:** `master`
**Tool:** CodeQL
**Filter:** `is:open branch:master tool:CodeQL`
**Total alerts:** 34 across 6 rule types

---

## Summary

| Group | Rule | Severity | Alerts | Resolution |
|---|---|---|---|---|
| [A](#group-a--ssn-and-sensitive-data-via-get-requests) | `rb/sensitive-get-query` | Medium | 7 | Needs research — POST refactor potentially in scope |
| [B](#group-b--reflected-xss-in-erb-views) | `rb/reflected-xss` | Medium | 4 | Fix: URL-encode params before interpolation |
| [C](#group-c--xss-through-dom-in-javascript) | `js/xss-through-dom` | High | 19 | Open questions — see below |
| [D](#group-d--clear-text-storage-of-sensitive-data-in-scripts) | `rb/clear-text-storage-sensitive-data` | High | 2 | Open questions — see below |
| [E](#group-e--insecure-gem-source-url) | `rb/insecure-dependency` | High | 1 | Immediate fix — one character change |
| [F](#group-f--overly-permissive-regex-range) | `js/overly-large-range` | Medium | 1 | Immediate fix — typo in regex |

---

## Group A — SSN and Sensitive Data via GET Requests

**Rule:** `rb/sensitive-get-query`
**Severity:** Medium
**Alerts:** #110, #112, #113, #117, #118, #119, #784, #3720

### What CodeQL found

Sensitive data (SSN, DOB, internal IDs) is being read from GET request parameters in several controller actions.

### Most Severe: SSN via GET AJAX — `hbx_profiles_controller.rb`

**Alerts:** #117, #118, #119 (lines 608, 616, 622)

The `verify_dob_change` action is routed GET-only and accepts `new_ssn` directly:

```ruby
# config/routes.rb line 454
match "hbx_profiles/verify_dob_change" => "exchanges/hbx_profiles#verify_dob_change",
  via: [:get], defaults: { format: 'js' }
```

The caller in `app/assets/javascripts/dob.js`:

```javascript
function check_dob_change_implication(person_id, new_dob, element_to_replace_id) {
  var new_ssn = $('#person_ssn').val();
  $.ajax({
    type: "GET",
    data: { person_id: person_id, new_dob: new_dob, new_ssn: new_ssn, family_actions_id: element_to_replace_id },
    url: "/hbx_profiles/verify_dob_change"
  });
}
```

SSN appears as a query string parameter in:
- Server access logs (nginx, Rails, load balancer, SIEM)
- Browser history
- HTTP Referer headers on any subsequent navigation
- Any analytics, APM, or log aggregation tooling that captures full URLs

`update_dob_ssn` (`hbx_profiles_controller.rb` line 616) is additionally routed with `via: [:get, :post]`, meaning it also accepts SSN via GET even though it's likely called via POST in practice.

### Lower Severity: Action IDs in GET Params

**Alerts:** #110, #112, #113, #784, #3720

These controllers read action/element IDs from GET params:

| Alert | Controller | Param | Action |
|---|---|---|---|
| #110 | `hbx_profiles_controller.rb:608` | `params[:family_actions_id]` | `verify_dob_change` |
| #112 | `employer_attestations_controller.rb:23` | `params[:employer_attestation_id]` | `verify_attestation` |
| #113 | `employer_attestations_controller.rb:77` | `params[:employer_attestation_id]` | `authorized_download` |
| #784 | `employer_attestations_controller.rb:9` | `params[:employer_actions_id]` | `edit` |
| #3720 | `employer_applications_controller.rb:16` | `params[:employers_action_id]` | `index` |

These are internal document/action identifiers rather than PII. The risk is lower but CodeQL flags them because they are read from GET parameters and could appear in server logs.

### Recommended Approach

**Flagged as potentially in scope — needs deeper research before committing to a fix.**

The immediate remedy for the SSN issue is:
1. Change the route for `verify_dob_change` from `via: [:get]` to `via: [:post]`
2. Change `dob.js` AJAX call from `type: "GET"` to `type: "POST"` and add a CSRF token
3. Change `update_dob_ssn` route from `via: [:get, :post]` to `via: [:post]` only

However, before making this change, investigate:
- Whether any other callers (other JS files, tests, external integrations) depend on the GET interface
- Whether removing GET support for `update_dob_ssn` breaks any existing workflows (it currently accepts both verbs)
- Whether SSN values have already been captured in existing log aggregation systems and what the disclosure policy is

---

## Group B — Reflected XSS in ERB Views

**Rule:** `rb/reflected-xss`
**Severity:** Medium
**Alerts:** #21, #22, #23, #24

### What CodeQL found

Request parameters are directly interpolated into URL strings without encoding, then passed to `link_to`. Rails' `link_to` HTML-escapes the `href` value, which prevents classic HTML injection, but the URL string itself is not URI-encoded — meaning special characters in the parameter value can break the URL structure (query string injection) and in edge cases where `html_safe` is present upstream, could become a direct XSS vector.

### `params[:employer_profile_id]` in URL path (alerts #21, #22)

**Files:**
- `app/views/employers/employer_profiles/_download_new_template.html.erb:10`
- `app/views/employers/employer_profiles/_file_not_attached_error.html.erb:6`

```erb
<%= link_to "Back To Employee Roster",
  "/employers/employer_profiles/#{params[:employer_profile_id]}?tab=employees",
  class: 'btn btn-primary' %>
```

`params[:employer_profile_id]` is interpolated directly into a URL path segment. In practice this value is expected to be a MongoDB ObjectId (24-character hex string), but there is no validation enforcing that constraint here.

**Fix:** Use a named route helper instead of string interpolation:
```erb
<%= link_to "Back To Employee Roster",
  employers_employer_profile_path(params[:employer_profile_id], tab: 'employees'),
  class: 'btn btn-primary' %>
```
Rails route helpers URI-encode path segments automatically.

### `params[:employee_search]` appended to URL (alerts #23, #24)

**Files:**
- `app/views/shared/_alph_paginate.html.erb:12`
- `components/benefit_sponsors/app/views/benefit_sponsors/shared/_alph_paginate.html.erb:12`

```erb
<% alph_url += "&employee_search=#{params[:employee_search]}" if params[:employee_search].present? %>
<li ...><%= link_to alph, (alph_url), remote: remote %></li>
```

`params[:employee_search]` is a free-text search input that is directly appended to a URL string without URI encoding. A value like `foo&admin=true` would inject an additional query parameter. The `_alph_paginate` partial is used in employee roster pages accessible to employer users (not just admins), making this the most exposed of the four alerts.

**Fix:** Use `CGI.escape` or pass params through the route helper:
```erb
<% alph_url += "&employee_search=#{CGI.escape(params[:employee_search].to_s)}" if params[:employee_search].present? %>
```

Note: `_alph_paginate` exists in both `app/views/shared/` and `components/benefit_sponsors/app/views/benefit_sponsors/shared/` — both copies need the same fix.

---

## Group C — XSS Through DOM in JavaScript

**Rule:** `js/xss-through-dom`
**Severity:** High
**Alerts:** #52–#70 (19 alerts across 6 files)

### What CodeQL found

jQuery's `.html()` is being called with values derived from DOM reads (`.text()`, `.val()`, `.attr()`), which CodeQL flags as a potential DOM-based XSS path. The concern is that if the DOM source was previously contaminated (e.g., via a separate injection), the `.html()` call could re-execute it.

### Files and patterns

| Alerts | File | Pattern |
|---|---|---|
| #52 | `employee_dependent.js:5` | `$(targetElementId).remove()` — `targetElementId` from `data-target` attr used as a jQuery selector |
| #53–#60 | `quotes/page_actions.js:125–146` | Numeric slider values (percentages) written to `.html()` |
| #61 | `_quote_household_fields.html.erb:60` | Server-rendered HTML string passed to `$('<div>...')` jQuery constructor |
| #62–#66 | `_view_hbx_enrollments.html.erb:124–150` | DOM `.text()` values (plan name, date) written to `.html()` via string concatenation |
| #67 | `_employers.html.erb:44` | `data-url` attribute read via `.attr()` and assigned to a variable (no `.html()` call visible at flagged line) |
| #68 | `old_sponsored_benefits/.../plan_design_proposals.js:279` | `effective_date`, `enrollment_market` from `td.text()` concatenated into `.html()` |
| #69–#70 | `sponsored_benefits/.../plan_design_proposals.js:439, 637` | Slider value via `.val()` written to `.html()` — numeric value |

### Assessment

Most of these are likely **false positives or very low practical risk**:

- Slider percentage values (`#53–#60`, `#69–#70`) are numeric, bounded 0–100 by the bootstrapSlider widget
- `employee_dependent.js` (`#52`) uses the value as a CSS selector for `.remove()`, not as HTML content
- The `_quote_household_fields` case (`#61`) builds HTML from a static ERB-rendered string, not runtime user input

The alerts most worth investigating further are **#62–#66** and **#68** — in `_view_hbx_enrollments` and `plan_design_proposals.js`, server-rendered text from `<td>` cells is concatenated with string literals and written via `.html()`. While `.text()` strips HTML tags, it doesn't prevent DOM clobbering if a prior injection modified those cells.

### Open Questions

The following need to be answered to make a confident recommendation:

1. **Are these pages admin/staff-only, or are any of them customer-facing?**
   The files span HbxProfiles admin views (`_view_hbx_enrollments`), broker quote tools (`quotes/page_actions.js`, `_quote_household_fields`), employee role views (`_employers.html.erb`), and sponsored benefits plan design (`plan_design_proposals.js`). If all flagged paths require an HBX staff or broker role, the attack surface is substantially smaller and dismissing these as accepted risk (with a comment) may be appropriate.

2. **Is there a separate XSS injection point that could contaminate the `<td>` cells read in `_view_hbx_enrollments` and `plan_design_proposals.js`?**
   If the server-rendered values in those table cells are already HTML-escaped by Rails (the default), DOM clobbering is not possible through normal data flow and these are false positives.

3. **Is the `old_sponsored_benefits` component (`#68`) still actively maintained and reachable?**
   If `components/old_sponsored_benefits/` is deprecated and the routes pointing to it have been removed, alert #68 can be dismissed.

### Recommended Path

- Confirm the access control role required for each flagged view
- If all flagged pages are admin/broker-only, dismiss alerts #52–#70 as accepted risk with a documented rationale
- If any are customer-facing, replace `.html()` with `.text()` where the content is plain text, or use `DOMPurify.sanitize()` before passing to `.html()`

---

## Group D — Clear-Text Storage of Sensitive Data in Scripts

**Rule:** `rb/clear-text-storage-sensitive-data`
**Severity:** High
**Alerts:** #809, #810

### What CodeQL found

Scripts in `script/` write sensitive personal data to unencrypted plain-text output files.

### `script/find_unlinked_employees.rb` (alert #809, line 36)

```ruby
csv << [email, first_name, last_name, hbx_id, employer_name, current_state]
```

Writes a CSV containing email address, full name, HBX ID, employer name, and employment state for each unlinked employee record.

### `script/policies_for_simulated_renewals.rb` (alert #810, line 108)

```ruby
initial_file.puts(enrollment_hbx_id)
renewal_file.puts(enrollment_hbx_id)
```

Writes enrollment HBX IDs to plain text files, split by initial/renewal type.

### Open Questions

The following need to be answered before recommending a remediation path:

1. **Are these scripts run against production data?**
   If they operate only against development or anonymized data, the risk is significantly lower. If they process live production records, PII exposure in plain-text output files is a compliance concern (HIPAA, depending on the data scope).

2. **Are these one-off historical scripts or part of a regular operational workflow?**
   Scripts that were run once and are now dormant are candidates for archival or deletion rather than remediation. Scripts used in regular data operations should have their output handling reviewed.

3. **What is the output file destination and who has access?**
   If these files are written to a secured, access-controlled directory (e.g., a private S3 bucket with encryption at rest) the risk profile is different than writing to a shared filesystem.

4. **Is there an existing policy around encrypting CSV data extracts?**
   If a standard exists (e.g., GPG-encrypting output before storage, or using `secure-spreadsheet` which is already installed in the reports image), the fix is to apply that same pattern here.

### Recommended Path

- Answer the questions above to determine if these scripts are still active
- If active and running against production data: apply output encryption (e.g., pipe through `secure-spreadsheet` or GPG) or anonymize sensitive fields before writing
- If dormant: consider archiving or deleting to reduce ongoing scanning noise

---

## Group E — Insecure Gem Source URL

**Rule:** `rb/insecure-dependency`
**Severity:** High
**Alert:** #783

**File:** `project_gems/mongoid_userstamp-0.4.0/Gemfile:1`

```ruby
source 'http://rubygems.org'  # ← HTTP, not HTTPS
```

The vendored `mongoid_userstamp` gem's `Gemfile` uses plain HTTP to reference RubyGems. This allows a network attacker in a man-in-the-middle position to substitute a malicious gem during a `bundle install`. While this gem is vendored locally (the `.gemspec` is in `project_gems/`), the `Gemfile` is still evaluated and could be invoked during builds.

**Fix:** One character change:

```ruby
source 'https://rubygems.org'
```

**File:** `project_gems/mongoid_userstamp-0.4.0/Gemfile:1`

---

## Group F — Overly Permissive Regex Range

**Rule:** `js/overly-large-range`
**Severity:** Medium
**Alert:** #51

**File:** `app/assets/javascripts/register.js:324`

```javascript
var email_regexp = /^[\w\-\.\+]+\@[a-zA-Z0-9\.\-]+\.[a-zA-z0-9]{2,4}$/;
//                                                              ^^^
//                                                        lowercase 'z' — typo
```

The character class `[a-zA-z]` (lowercase `z`) matches not just letters but also the ASCII characters between `Z` (90) and `a` (97): `[`, `\`, `]`, `^`, `_`, and `` ` ``. This means the TLD portion of an email address would incorrectly accept characters like `foo@example.com]` as valid.

This is a typo — the intended range is `[a-zA-Z]`.

**Fix:**

```javascript
var email_regexp = /^[\w\-\.\+]+\@[a-zA-Z0-9\.\-]+\.[a-zA-Z0-9]{2,4}$/;
```

Note: This regex also only accepts TLDs of 2–4 characters, which excludes modern TLDs like `.health`, `.online`, etc. This is a separate issue but worth considering if email validation failures have been reported.

---

## Remediation Priority Order

| Priority | Alert(s) | Action | Effort |
|---|---|---|---|
| **1 — Do now** | #783 | Change `http://` → `https://` in `mongoid_userstamp` Gemfile | < 5 min |
| **2 — Do now** | #51 | Fix regex typo `[a-zA-z]` → `[a-zA-Z]` in `register.js` | < 5 min |
| **3 — Do soon** | #21, #22 | Replace string interpolation with `employers_employer_profile_path()` route helper | ~15 min |
| **4 — Do soon** | #23, #24 | Add `CGI.escape()` around `params[:employee_search]` in both copies of `_alph_paginate.html.erb` | ~15 min |
| **5 — Research first** | #117–#119 | Investigate feasibility of moving SSN off GET params in `verify_dob_change` / `update_dob_ssn` | Research spike |
| **6 — Answer questions** | #809, #810 | Determine if scripts run against prod data; apply encryption or archive | Needs context |
| **7 — Answer questions** | #52–#70 | Confirm access control roles for flagged views; dismiss or fix based on findings | Needs context |

## Open Items Tracking

- [ ] **Group A:** Determine downstream effects of changing `verify_dob_change` to POST-only (route, JS, tests, any external callers)
- [ ] **Group A:** Audit whether `update_dob_ssn` is ever called via GET in practice; restrict to POST-only if not
- [ ] **Group C:** Confirm whether all XSS-through-DOM flagged views require admin/broker authentication
- [ ] **Group C:** Confirm whether `old_sponsored_benefits` component is still active and reachable
- [ ] **Group C:** Confirm whether server-rendered `<td>` values in `_view_hbx_enrollments` and `plan_design_proposals.js` are HTML-escaped at the source
- [ ] **Group D:** Confirm whether `find_unlinked_employees.rb` and `policies_for_simulated_renewals.rb` are run against production data
- [ ] **Group D:** Confirm operational status (active vs. dormant) of both scripts
- [ ] **Group D:** Confirm output file destination and access controls
