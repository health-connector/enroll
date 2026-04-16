# Bearer Security Findings Report

**Generated:** 2026-04-14
**Branch scanned:** `master`
**Tool:** Bearer
**Filter:** `is:open branch:master tool:Bearer`
**Total alerts:** 178 across 19 rule types

---

## Summary

| Group | Rule(s) | Severity | Alerts | Resolution |
|---|---|---|---|---|
| [A](#group-a--open-redirect-via-requestreferrer) | `ruby_rails_open_redirect` | Error | 6 | Fix: validate referrer or replace with safe fallback |
| [B](#group-b--unsafe-innerhtml-in-application-javascript) | `javascript_lang_dangerous_insert_html` | Error | 4 | Fix `benefit_application.js`; #467 is false positive (controller unwired); 5 vendored/dismissed |
| [C](#group-c--permissive-parameters-permitin-application-code) | `ruby_rails_permissive_parameters` | Error | 11 | 2 real (users_controller, broker_applicants); 2 real but Virtus-mitigated; `family_members` create unfiltered; 3 vendored |
| [D](#group-d--hardcoded-secrets) | `ruby_lang_hardcoded_secret` | Error | 32 | Mostly false positives (test fixtures, Devise translations) — 2 real dev config entries |
| [E](#group-e--sensitive-data-in-file-generation) | `ruby_lang_file_generation` | Error | 70 | Same category as CodeQL Group D — needs operational context |
| [F](#group-f--dangerous-eval-in-rake-tasks) | `ruby_lang_eval_linter` | Error | 12 | Low practical risk — local variable, not user input; 4 in test code |
| [G](#group-g--unsanitized-html-body-in-agent-mailbox-message) | `ruby_lang_raw_html_using_user_input` | Error | 1 | False positive — body rendered via `sanitize()`, not `raw`/`html_safe`; defence-in-depth fix still recommended |
| [H](#group-h--weak-md5-hash-for-enrollment-signature) | `ruby_lang_weak_hash_md` | Error | 1 | Low risk — deduplication signature, not auth |
| [I](#group-i--sql-injection-false-positives-in-mongoid-context) | `ruby_rails_sql_injection` | Error | 6 | Mostly false positives (Mongoid) — 3 in vendored gem |
| [J](#group-j--logger-and-exception-data-leakage) | `ruby_rails_logger`, `javascript_lang_logger_leak`, `ruby_lang_exception` | Error | 7 | Minor — console.log in JS, PII in Rails error log |
| [K](#group-k--path-traversal-false-positive) | `ruby_lang_path_using_user_input` | Error | 1 | False positive — protected by allowlist check |
| [L](#group-l--unsafe-mass-assignment-false-positive) | `ruby_rails_unsafe_mass_assignment` | Error | 1 | False positive — explicit permit() list follows |
| [M](#group-m--vendored-third-party-javascript) | Multiple | Error | 25 | Dismiss — entirely in vendored gems/libraries |

---

## Group A — Open Redirect via `request.referrer`

**Rule:** `ruby_rails_open_redirect`
**Severity:** Error
**Alerts:** #743, #744, #745, #746, #814, #815

### What Bearer found

The `user_not_authorized` Pundit handler and one families controller action redirect to `request.referrer` without validating that the referrer is a trusted host. The `Referer` HTTP header is fully attacker-controlled — a malicious link can set it to any URL.

**Pattern repeated across all base controllers:**

```ruby
# app/controllers/application_controller.rb:76
format.html { redirect_to(request.referrer || root_path) }

# components/benefit_sponsors/app/controllers/benefit_sponsors/application_controller.rb:127
format.html { redirect_to(session[:custom_url] || request.referrer || main_app.root_path) }

# components/notifier, components/sponsored_benefits (identical pattern)
```

**Attack scenario:** An attacker crafts a link to any enroll page that the target user lacks permission to view (triggering Pundit's `user_not_authorized`), with the `Referer` header pointed at `https://attacker.com`. The server then issues a `302` redirect to the attacker's site. Because the redirect comes from the trusted `mahealthconnector.org` domain, phishing pages can reference it for legitimacy.

**Alert #744 (`insured/families_controller.rb:102`) context:** This alert redirects to `continuous_plan_shopping(action_params)` — a route helper, not a raw referrer. This is a **false positive**; the redirect target is always an internal path.

### Recommended Fix

Replace `request.referrer` with a safe fallback. Rails provides `url_from` (Rails 7.1+) for exactly this:

```ruby
# Safe version
format.html { redirect_to(url_from(request.referrer) || root_path) }
```

`url_from` returns `nil` if the referrer points to a different host, so the `|| root_path` fallback fires for off-site values. Apply this change to all four base controllers:

| File | Line |
|---|---|
| `app/controllers/application_controller.rb` | 76 |
| `components/benefit_sponsors/app/controllers/benefit_sponsors/application_controller.rb` | 127 |
| `components/notifier/app/controllers/notifier/application_controller.rb` | 27 |
| `components/sponsored_benefits/app/controllers/sponsored_benefits/application_controller.rb` | 32 |

`session[:custom_url]` in the `benefit_sponsors` controller also needs validation — confirm that custom_url is set from a trusted internal source before the session value is used.

---

## Group B — Unsafe `innerHTML` in Application JavaScript

**Rule:** `javascript_lang_dangerous_insert_html`
**Severity:** Error
**Alerts:** 9 total — **4 in application code**, 5 in vendored libraries

### Vendored alerts (dismiss)

| Alert | File | Notes |
|---|---|---|
| #3053, #473, #470 | `project_gems/effective_datatables-2.6.14/…` | Vendored gem — not our code |
| #469, #468 | `components/notifier/…/ckeditor/…` | Vendored CKEditor — not our code |

### Application code alerts (investigate)

#### `app/javascript/legacy/benefit_application.js` (#464, #465, #466)

```javascript
// lines 7, 26, 44
document.getElementById('employerCostTitle').innerHTML = '';
document.getElementById('rpEstimatedMonthlyCost').innerHTML = ('$ ' + cost);

tr.innerHTML = `
  <td>${estimate.name}</td>
  <td>${estimate.dependent_count}</td>
  <td>$ ${estimate.lowest_cost_estimate}</td>
  ...
`
```

The third call (#466, line 44) interpolates `estimate.name`, `estimate.dependent_count`, and cost figures from a JavaScript object (`employees_cost`) into `tr.innerHTML`. If the `employees_cost` object comes from an API response that includes user-controlled data (e.g., census employee name), this is a stored XSS vector.

**Fix:** Replace with `textContent` for plain text values, or sanitize with DOMPurify:

```javascript
const td = document.createElement('td');
td.textContent = estimate.name;  // safe for text
tr.appendChild(td);
```

#### `app/javascript/ui_components/controllers/ux-plan-filter_controller.js` (#467, line 46) — **False positive**

```javascript
title.innerHTML = JSON.parse(p).title;
```

`productArray` is built from `JSON.parse(filteredDiv.dataset.availableProduct)` — data from the DOM `data-available-product` attribute. A repository-wide search finds **no template in the current tree that sets `data-available-product`** on `#filteredPlans`; the Stimulus controller identifier also appears nowhere else. This controller is not wired to any live page.

In the active plan shopping path, comparable display data comes from `json_for_plan_shopping_member_groups` in `app/helpers/application_helper.rb`, which builds hashes from server-side enrollment objects and issuer profile records — not from user-controlled text fields.

**Assessment:** False positive and likely dead code. Dismiss alert #467. If the controller is ever wired up, ensure `title` values come from a server-escaped source.

---

## Group C — Permissive Parameters (`permit!`) in Application Code

**Rule:** `ruby_rails_permissive_parameters`
**Severity:** Error
**Alerts:** 14 total — **11 in application code**, 3 in vendored gem

### Vendored alerts (dismiss)

Alerts #5059, #5058, #5057 are in `project_gems/effective_datatables-2.6.14/app/controllers/effective/datatables_controller.rb` — not our code.

### Real application alerts

#### `app/controllers/users_controller.rb:6` (alert #756)

```ruby
def confirm_lock
  authorize HbxProfile, :confirm_lock?
  params.permit!
  @user_id = params[:user_action_id]
end
```

`params.permit!` allows all parameters through. This action is HBX admin-only (Pundit-guarded), but `permit!` is still a code smell — only `user_action_id` is actually needed.

**Fix:**
```ruby
params.permit(:user_action_id)
```

#### `app/controllers/exchanges/broker_applicants_controller.rb` (#751, #752, #753)

```ruby
broker_role.update(params.require(:person).require(:broker_role_attributes).permit!.except(:id))
```

`permit!` on broker role attributes allows any attribute on the broker role to be mass-assigned, including fields like `aasm_state`, `market_kind`, or `npn`. The `.except(:id)` guard only blocks the primary key. This action is admin-only, but the overly broad permit expands the blast radius of any authorization bypass.

**Fix:** Enumerate the permitted broker role attributes explicitly:
```ruby
params.require(:person).require(:broker_role_attributes)
      .permit(:license, :county_zip_ids, :market_kind, :npn, :carrier_appointments => {})
```

#### `app/controllers/insured/family_members_controller.rb` (#754) and `app/models/forms/family_member.rb` (#4637) — **Real, higher severity**

```ruby
# create action
Forms::FamilyMember.new(params[:dependent])   # no permit — raw params passed to form

# update — resident-primary path
@dependent.update_attributes(params.require(:dependent))  # require but no permit
```

The `create` action and the resident-primary `update` path pass **unfiltered `params[:dependent]`** directly to the form object, bypassing Rails strong parameters entirely. The consumer/employee `update` path correctly uses `dependent_person_params`, an explicit permit list covering ~30 named fields.

`Forms::FamilyMember` accepts person attributes including `ssn`, `gender`, `dob`, `tribal_id`, `is_incarcerated`, citizenship flags, addresses, and consumer role fields. Extra keys that the form object passes to the Person model via `save` could set unintended attributes.

**Fix:** The explicit permit list already exists in `dependent_person_params` / `person_parameters_list`. Apply it to the `create` action and the resident-primary `update` branch:

```ruby
# create
Forms::FamilyMember.new(dependent_person_params.to_h)

# update — resident path
@dependent.update_attributes(dependent_person_params.to_h)
```

#### `BenefitSponsors::Profiles::RegistrationsController` (#761, #760) — **Real, partially mitigated**

```ruby
# registration_params
params[:agency].permit!
```

`permit!` allows any nested key under `agency` at the Rails layer. However, input is then passed to `OrganizationForms::RegistrationForm`, a Virtus form object with typed attribute definitions. Virtus ignores keys that don't map to declared attributes, providing a **secondary layer of filtering** — extra keys under `agency` reach form initialization but are not persisted.

The form handles sensitive data: ACH bank account fields (`ach_account_number`, `ach_routing_number`, `ach_routing_number_confirmation`) in the broker profile path, and organization/office location attributes broadly.

**Fix:** Replace `params[:agency].permit!` with an explicit allowlist scoped to what the form actually receives. The intended fields per view are:
- Employer: `legal_name`, `dba`, `fein`, `entity_kind`, `sic_code`, `referred_by`, `referred_reason`, `contact_method`, nested `office_locations` (address + phone), nested `staff_roles` (first_name, last_name, dob, email, area_code, number, extension)
- Broker: adds `npn`, `market_kind`, `languages_spoken`, `working_hours`, `accept_new_clients`, ACH fields

#### `BenefitSponsors::Profiles::Employers::EmployerStaffRolesController` (#759) — **Real, partially mitigated**

```ruby
params[:staff].permit!
```

The add-staff form only submits `first_name`, `last_name`, and `dob`, but `permit!` also allows `npn`, `email`, `phone`, `status`, `profile_type` (all declared on `StaffRoleForm`). The Virtus form again provides secondary filtering.

**Fix:**
```ruby
params.fetch(:staff, {}).permit(:first_name, :last_name, :dob, :email, :npn, :area_code, :number, :extension)
```

#### Other application alerts

| Alert | File | Assessment |
|---|---|---|
| #5474 | `benefit_sponsors/.../benefit_package_form_params_builder.rb:22` | `permit!` on benefit package form — enumerate permitted fields |
| #804 | `benefit_sponsors/.../sponsored_benefit_form.rb:39` | `permit!` on sponsored benefit form — enumerate permitted fields |

These two follow the same pattern as the registrations controller — a Virtus form object provides secondary filtering, but `permit!` at the controller layer should still be replaced with an explicit list.

---

## Group D — Hardcoded Secrets

**Rule:** `ruby_lang_hardcoded_secret`
**Severity:** Error
**Alerts:** 32

### False positives (28 alerts — dismiss)

**Cucumber/feature step definitions** (alerts #794, #338–#360 in `features/`): These are test fixture credentials — hardcoded SSNs, passwords like `'aA1!aA1!aA1!'`, and example emails used in integration tests. They represent test data, not production secrets. No action needed.

**Devise translation seed files** (alerts #328–#338 in `db/seedfiles/translations/`, `components/*/db/seedfiles/`): These files contain only UI string translations for Devise emails and forms. Bearer incorrectly identifies translation key values as secrets. These are false positives — no secrets are present.

### Real findings (2 alerts — `config/environments/development.rb`)

**Alerts #333, #334 (lines 83, 85)**

```ruby
# config/environments/development.rb
config.wells_fargo_api_key = 'e2dab122-114a-43a3-aaf5-78caafbbec02'
config.wells_fargo_api_secret = 'dchbx 2017'
```

These are Wells Fargo demo/sandbox API credentials hardcoded directly in `development.rb`. Even though they appear to be sandbox values (the URL points to a demo host), hardcoding credentials in version-controlled config is against best practice.

**Fix:** Move to environment variables:

```ruby
config.wells_fargo_api_key = ENV.fetch('WELLS_FARGO_API_KEY', nil)
config.wells_fargo_api_secret = ENV.fetch('WELLS_FARGO_API_SECRET', nil)
```

Add the default sandbox values to `.env.development.local` (gitignored) or to the deployment secrets store.

---

## Group E — Sensitive Data in File Generation

**Rule:** `ruby_lang_file_generation`
**Severity:** Error
**Alerts:** 70

### What Bearer found

70 alerts across `script/` files and `lib/tasks/hbx_reports/` rake tasks write data to CSV or plain-text output files. Bearer flags these because the data flowing to the files is derived from model records that may contain PII (names, emails, HBX IDs, enrollment IDs, SSNs).

This is the same category as **CodeQL Group D** in the existing CodeQL report (`rb/clear-text-storage-sensitive-data`), which also flagged `script/find_unlinked_employees.rb` and `script/policies_for_simulated_renewals.rb`. Bearer's detection is broader and has found 70 additional instances across the entire report/task inventory.

### Affected files (sample)

| File | What is written |
|---|---|
| `script/extract_users_with_internal_roles.rb` | Internal user roles and identifiers |
| `script/ea_access_list.rb` | Employer access/contact data |
| `script/clean_and_report_bad_user_records.rb` | User account data |
| `script/duplicate_addresses_report.rb` | Address and person data |
| `script/congressional_report.rb` | Enrollment and demographic data |
| `lib/tasks/hbx_reports/*.rake` | 40+ report tasks generating CSV extracts |
| `app/reports/outstanding_types_report.rb` | Verification/outstanding document data |
| `lib/converge_voids.rb` | Enrollment void processing |

### Open questions (same as CodeQL Group D)

The same four questions from the CodeQL report apply here at broader scope:

1. **Are these scripts run against production data?** The answer determines whether this is a compliance exposure (HIPAA) or a development-only concern.
2. **Are these operational/recurring or historical one-offs?** Recurring tasks need output encryption or anonymization; dormant scripts are candidates for deletion.
3. **What is the output file destination and access control?** Encrypted S3 with restricted access is materially different from a shared filesystem.
4. **Is there an existing policy for encrypting CSV extracts?** If a standard exists (e.g., `secure-spreadsheet`, GPG), these tasks should use it.

### Recommended path

Given the scale (70 alerts vs. the 2 previously identified by CodeQL), the immediate priority is to triage by whether each script is:
- **Active + production data:** Apply encryption or anonymization
- **Active + anonymized/dev data:** Document and dismiss
- **Dormant:** Archive or delete to reduce scanning noise

---

## Group F — Dangerous `eval()` in Rake Tasks

**Rule:** `ruby_lang_eval_linter`
**Severity:** Error
**Alerts:** 12

### Test code (dismiss)

Alerts #173–#176 are in `features/step_definitions/` — Cucumber test code. These use `eval` in test scaffolding and present no production risk.

### Rake report tasks (alerts #178–#185)

```ruby
# lib/tasks/hbx_reports/employer_plan_year_status.rake:60,62
csv << field_names.map do |field_name|
  if field_name == "fein"
    '="' + eval(field_name) + '"'
  else
    eval("#{field_name}")
  end
end
```

`eval(field_name)` is called where `field_name` iterates over a local `field_names` array that is hardcoded within the rake task. The values are local variable names like `"fein"`, `"employer_name"`, etc. — **not user input**.

This is a **low-risk false positive in practice** — there is no code path from user input to `field_name`. However, `eval` on variable names is an antipattern:
- It fails if the variable name changes without updating `field_names`
- It makes refactoring harder to track
- Any future change that makes `field_names` dynamic would become a real injection vector

**Better pattern:**

```ruby
# Instead of eval, use a method or hash lookup
field_map = {
  'fein'          => -> { '="' + fein + '"' },
  'employer_name' => -> { employer_name },
  # ...
}
csv << field_names.map { |f| field_map[f]&.call }
```

This change is low-urgency but is a safe improvement.

---

## Group G — Unsanitized HTML Body in Agent Mailbox Message

**Rule:** `ruby_lang_raw_html_using_user_input`
**Severity:** Error
**Alert:** #813

**File:** `app/controllers/exchanges/agents_controller.rb:28`

```ruby
root = "http://#{request.env['HTTP_HOST']}/exchanges/agents/resume_enrollment?person_id=#{person_id}"
message_params = {
  body: "<a href='#{root}'>Link to access #{@person.full_name}</a>  <br>"
}
```

`@person.full_name` is a user-supplied name interpolated directly into an HTML string without escaping. This would be a stored XSS vector if the body were rendered without sanitization.

### Answer — **False positive**

`app/views/exchanges/agents/_message.html.erb` renders the body as:

```erb
<%= sanitize(message.try(:body)) %>
```

Rails' `sanitize` strips disallowed tags and attributes before rendering. The body is **not** rendered with `raw` or `.html_safe` anywhere in the agent inbox flow (the detail partial, the AJAX show action in `agents_inboxes/show.js.erb`, or the list partial `_individual_message.html.erb`). The generic shared `app/views/shared/inboxes/_message.html.erb` also uses `sanitize`.

### Recommended fix (defence in depth, not urgent)

Even though `sanitize` at render time provides a working defence, escaping at the point of construction is still best practice — it makes the code correct regardless of how the value is later used:

```ruby
body: "<a href='#{ERB::Util.html_escape(root)}'>Link to access #{ERB::Util.html_escape(@person.full_name)}</a><br>"
```

---

## Group H — Weak MD5 Hash for Enrollment Signature

**Rule:** `ruby_lang_weak_hash_md`
**Severity:** Error
**Alert:** #679

**File:** `app/models/hbx_enrollment.rb:269`

```ruby
def generate_hbx_signature
  self.enrollment_signature = Digest::MD5.hexdigest(self.subscriber.applicant_id.to_s)
end
```

MD5 is a cryptographically broken hash function. However, the `enrollment_signature` field is used as a **deduplication key** for enrollment records, not for authentication or password storage. MD5 collisions require crafted input — they are not a practical concern for this use case (hashing internal MongoDB ObjectIDs).

**Assessment:** This is **low risk in context** — the signature is not used to verify identity or protect secrets. The practical fix would be to replace with `Digest::SHA256`, which requires confirming that `enrollment_signature` is not used in any external integrations that depend on the MD5 format.

---

## Group I — SQL Injection (False Positives in Mongoid Context)

**Rule:** `ruby_rails_sql_injection`
**Severity:** Error
**Alerts:** 6 total — 3 in vendored gem, 3 in application code

### Vendored alerts (dismiss)

Alerts #394, #395, #396 are in `project_gems/effective_datatables-2.6.14/app/models/effective/active_record_datatable_tool.rb`. This is a vendored gem for an ActiveRecord context; the project uses MongoDB/Mongoid, making these alerts inapplicable to the production database path.

### Application code alerts (false positives)

| Alert | File | Code |
|---|---|---|
| #377 | `app/models/hbx_enrollment.rb:1058` | `household.hbx_enrollments.where(id: id).update_all(updates)` |
| #378 | `app/models/hbx_enrollment_member.rb:43` | `hbx_enrollment.hbx_enrollment_members.where(id: id).update_all(updates)` |
| #376 | `app/domain/operations/census_members/update.rb:118` | `census_dependents.where(matching_criteria(person)).first` |

All three use Mongoid's query interface, which uses BSON — not SQL. `update_all(updates)` accepts a hash of field-value pairs, not a raw query string. The `updates` argument is passed from internal callers with typed values.

**Assessment:** These are **false positives** — Mongoid's `update_all` with a hash argument does not construct SQL. Dismiss.

---

## Group J — Logger and Exception Data Leakage

**Rules:** `ruby_rails_logger`, `javascript_lang_logger_leak`, `ruby_lang_exception`
**Severity:** Error
**Alerts:** 7 (alerts #742, #774, #775, #777, #8414, #675, #676)

### Rails logger (#742)

`components/benefit_sponsors/.../reinstate.rb:133`

```ruby
Rails.logger.error "Error while reinstating benefit group assignment for #{census_employee.full_name}(#{census_employee.id}) #{e}"
```

Logs the census employee's full name and internal ID in an error message. This is reasonable operational logging for debugging production issues, but `full_name` is PII. If logs are forwarded to a third-party log aggregator (Datadog, Splunk, etc.), confirm that PII handling meets HIPAA requirements.

### JavaScript console.log (#774, #775, #777, #8414)

`app/assets/javascripts/insured/members_selection.js:21,25` and others log JavaScript values to the browser console. These are developer debugging calls that should not contain PII but are still flagged by Bearer as potential information leakage. Review whether any logged values include member IDs or plan details; if so, remove the `console.log` calls.

### Exception message leakage (#675, #676)

`script/open_enrollment_sequence.rb:36,40` — exception messages may contain sensitive data. This is an operational script; the same operational-context questions from Group E apply.

---

## Group K — Path Traversal (False Positive)

**Rule:** `ruby_lang_path_using_user_input`
**Severity:** Error
**Alert:** #594

**File:** `app/controllers/employers/census_employees_controller.rb:188`

```ruby
def confirm_effective_date
  confirmation_type = params[:type]
  return unless CensusEmployee::CONFIRMATION_EFFECTIVE_DATE_TYPES.include?(confirmation_type)
  render "#{confirmation_type}_effective_date"
end
```

Bearer flags `params[:type]` flowing into `render "#{confirmation_type}_effective_date"`. However, the `return unless` guard enforces an allowlist check — `confirmation_type` can only be a value from `CONFIRMATION_EFFECTIVE_DATE_TYPES` before reaching the render call. This is a **false positive**; the allowlist pattern is correct.

---

## Group L — Unsafe Mass Assignment (False Positive)

**Rule:** `ruby_rails_unsafe_mass_assignment`
**Severity:** Error
**Alert:** #1841

**File:** `app/controllers/exchanges/hbx_profiles_controller.rb:952`

```ruby
def create_ba_params
  params.merge!({ pte_count: '0', msp_count: '0', admin_datatable_action: true })
  params.permit(:start_on, :end_on, :fte_count, :pte_count, :msp_count,
                :open_enrollment_start_on, :open_enrollment_end_on,
                :benefit_sponsorship_id, :admin_datatable_action, :has_active_ba)
end
```

Bearer flags `params.merge!` as potentially allowing mass assignment of dangerous keys. However, the `permit` call that immediately follows explicitly whitelists only specific named keys — anything not on the list is stripped by Rails. The `merge!` only adds internal server-set values (`pte_count`, `msp_count`, `admin_datatable_action`). This is a **false positive**.

---

## Group M — Vendored / Third-Party JavaScript

**Rules:** Multiple
**Alerts:** 25

The following alerts are entirely within vendored third-party code. They should be dismissed as a group.

| Rule | Alerts | Location |
|---|---|---|
| `javascript_express_nosql_injection` | #155 | `project_gems/effective_datatables-2.6.14/…/buttons.html5.js:276` |
| `javascript_lang_dynamic_regex` | #632–#640 (9 alerts) | `vendor/`, `project_gems/effective_datatables`, `components/notifier/ckeditor` |
| `javascript_lang_insufficiently_random_values` | #771, #772 | `vendor/assets/javascripts/floatlabels.js`, CKEditor |
| `javascript_lang_manual_html_sanitization` | #495 | CKEditor `dialogui/plugin.js` |
| `javascript_lang_observable_timing` | #659, #660, #661 | CKEditor `lineutils/plugin.js` |
| `javascript_lang_dynamic_regex` (app) | #5322, #5323 | `glossary.js` — same file in two locations; low risk (search highlight regex) |

**Note on `glossary.js` (#5322, #5323):** These appear in both `app/assets/javascripts/glossary.js` and `components/sponsored_benefits/…/glossary.js`. The regex is built from a search term to highlight matching text. The term comes from user input but is used only as a DOM search pattern — not injected as HTML. Risk is low; the fix would be to escape special regex characters using `term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')`.

---

## Remediation Priority Order

| Priority | Alert(s) | Action | Effort |
|---|---|---|---|
| **1 — Fix now** | #743, #745, #746, #815 | Replace `request.referrer` with `url_from(request.referrer)` in all 4 base controllers | ~30 min |
| **2 — Fix now** | #333, #334 | Move Wells Fargo dev credentials to environment variables | ~15 min |
| **3 — Fix soon** | #754, #4637 | Apply `dependent_person_params` permit list to `create` action and resident-primary `update` in `family_members_controller.rb` | ~30 min |
| **3 — Fix soon** | #756 | Replace `params.permit!` with `params.permit(:user_action_id)` in `users_controller.rb` | ~5 min |
| **3 — Fix soon** | #751–#753 | Replace `permit!` with an explicit allowlist in `broker_applicants_controller.rb` | ~20 min |
| **3 — Fix soon** | #464–#466 | Replace `tr.innerHTML` template literal with DOM element creation in `benefit_application.js` | ~30 min |
| **4 — Fix when convenient** | #761, #760 | Replace `params[:agency].permit!` with explicit allowlist in `registrations_controller.rb` (Virtus mitigates, but remove the Rails bypass) | ~45 min |
| **4 — Fix when convenient** | #759 | Replace `params[:staff].permit!` with explicit allowlist in `employer_staff_roles_controller.rb` | ~15 min |
| **4 — Fix when convenient** | #813 | Apply `ERB::Util.html_escape` to `full_name` and `root` in `agents_controller.rb:28` (defence in depth — `sanitize` already applied at render) | ~5 min |
| **5 — Research first** | #506–#576 (70 alerts) | Determine operational status and data scope of all file-generation scripts/tasks | Research spike |
| **6 — Low urgency** | #178–#185 | Replace `eval(field_name)` in rake tasks with hash/lambda lookup | ~1 hr |
| **7 — Low urgency** | #679 | Consider migrating `generate_hbx_signature` from MD5 to SHA256 | Research |
| **Dismiss** | #155, #394–#396, #469–#470, #473, #495, #632–#640, #659–#661, #771–#772, #3053 | Vendored third-party code — no action needed | — |
| **Dismiss** | #376–#378 | Mongoid false positives — no SQL injection vector | — |
| **Dismiss** | #467 | `ux-plan-filter_controller.js` not wired to any live template; data path is server-controlled | — |
| **Dismiss** | #594, #1841 | False positives — protected by allowlist/explicit permit | — |
| **Dismiss** | #813 (as a vulnerability) | Body rendered via `sanitize()` — not a live XSS vector; defence-in-depth fix still recommended | — |
| **Dismiss** | #328–#360 (test/seed) | Test fixture credentials and Devise translation seeds | — |

---

## Open Items Tracking

- [ ] **Group A:** Confirm `session[:custom_url]` in `benefit_sponsors` ApplicationController is always set from a trusted internal source (not user-supplied)
- [x] **Group B (#467):** ~~Trace the source of `productArray`~~ — Confirmed false positive. Controller not wired to any live template; data in active plan shopping path is server-controlled via `json_for_plan_shopping_member_groups`.
- [x] **Group G (#813):** ~~Confirm whether agent inbox renders mailbox `body` with `raw`/`html_safe`~~ — Confirmed false positive. `app/views/exchanges/agents/_message.html.erb` uses `sanitize(message.try(:body))`.
- [x] **Group C:** ~~Enumerate permitted fields for registrations, family_members, employer_staff_roles controllers~~ — Researched. Key finding: `family_members_controller` `create` and resident-primary `update` are genuinely unfiltered (highest priority). `registrations_controller` and `employer_staff_roles_controller` use `permit!` but are partially mitigated by Virtus form objects. See Group C section for recommended explicit allowlists.
- [ ] **Group E:** Determine operational status (active vs. dormant) and data scope (production vs. dev/anonymized) for all 70 file-generation scripts and rake tasks — same question as CodeQL Group D, now at broader scope
- [ ] **Group H:** Confirm `enrollment_signature` is not consumed by any external system expecting MD5 format before migrating to SHA256
