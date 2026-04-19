# Enroll App — Shared QA & Dev Knowledge

This file is referenced by all skills. It documents codebase quirks, gotchas, and
patterns discovered through hands-on session work. Always consult this before diving
into a new scenario or investigation.

---

## Dev Environment Essentials

| Thing | Detail |
|---|---|
| Local URL | `http://localhost:3000` |
| RVM command | `source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma` |
| Run seed scripts | `bundle exec rails runner .aidocs/seeds/<script>.rb` |
| ClickUp workspace | `9011313074` |
| ClickUp screenshot task | `868jahba6` (permanent, do not delete) |

RVM gemset: The repo's `.ruby-gemset` can override `rvm use`. Always prefix with
`source ~/.rvm/scripts/rvm && rvm use 3.4.7@ma` or use the wrapper in `.aidocs/seeds/helpers.rb`.

---

## Known Dev DB / Seed Gotchas

### 1. SymmetricEncryption cipher errors on UI form submit
- **Cause:** Seeded records have SSN/DOB encrypted with cipher v1, which is not in the dev config.
- **Symptom:** 500 error when submitting forms that touch SSN/DOB fields (census employee edit, etc).
- **Fix:** Use `rails runner` to test model methods directly, or use freshly created (not seeded) records.

### 2. Employer attestation stuck at `unsubmitted`
- **Cause:** New `AcaShopCcaEmployerProfile` instances start with no `EmployerAttestation` or `aasm_state: "unsubmitted"`.
- **Symptom:** "Attestation Pending" — plan year cannot be published.
- **Fix (model method):**
  ```ruby
  profile = org.employer_profile
  attestation = profile.employer_attestation || profile.build_employer_attestation
  attestation.update_attribute(:aasm_state, "approved")
  profile.save!(validate: false)
  ```
- **Fix (MongoDB direct):**
  ```js
  db.benefit_sponsors_organizations_organizations.updateOne(
    { "profiles.aasm_state": { $exists: false }, "profiles._id": ObjectId("...") },
    { $set: { "profiles.$.employer_attestation.aasm_state": "approved" } }
  )
  ```

### 3. Seeded census employees missing benefit_group_assignments
- **Cause:** Pre-seeded employees were created before the benefit package existed.
- **Symptom:** "All employees must have a benefit package" error when publishing plan year.
- **Fix:**
  ```ruby
  CensusEmployee.where(benefit_sponsors_employer_profile_id: profile.id).each do |ce|
    next if ce.benefit_group_assignments.any? { |bga| bga.benefit_package_id == package.id }
    ce.benefit_group_assignments.create!(
      benefit_package_id: package.id,
      start_on: [package.start_on, ce.hired_on].compact.max,
      is_active: true
    )
    ce.save!(validate: false)
  end
  ```

### 4. New hire eligibility period blocked
- **Cause:** `CensusEmployee#new_hire_enrollment_period` is calculated from `created_at` + `hired_on`. If `created_at` is too recent relative to `hired_on`, eligibility start is in the future.
- **Symptom:** Employee can't enroll — "not in an eligible enrollment period".
- **Fix:**
  ```ruby
  ce = CensusEmployee.find("...")
  ce.set(created_at: ce.hired_on.to_time)
  ```

### 5. Rating area blank for employer
- **Cause:** Not all zip codes have a `BenefitMarkets::Locations::RatingArea` record in dev.
- **Symptom:** Validation error on benefit application — no rating area found.
- **Fix:** Use zip `01247` (Berkshire County, MA) — confirmed to have rating area and service area mapped in dev seed data.

### 6. Employer zip setting for valid rating area
- The rating area is derived from `primary_office_location.address` when the profile is saved.
- To change the zip, update the `primary_office_location.address.zip` field on the profile.

---

## Playwright / Browser Automation Patterns

These are copy-paste snippets for common Enroll-specific browser interactions.

### jQuery Datepicker — set both fields
Date inputs in Enroll use a **visible** `MM/DD/YYYY` display field AND a **hidden** `YYYY-MM-DD`
value field. Playwright's `fill()` only updates the visible field. Always set both:

```javascript
// In page.evaluate() — replace selectors and values as needed
document.querySelector('input#census_employee_dob').value = '01/15/1990';
document.querySelector('input[name="census_employee[dob]"]').value = '1990-01-15';

document.querySelector('input#census_employee_hired_on').value = '01/01/2026';
document.querySelector('input[name="census_employee[hired_on]"]').value = '2026-01-01';
```

### Employee Signup — set both email AND oim_id
The signup form has two separate fields: `user[email]` and `user[oim_id]`. Standard `fill()`
only reaches the visible email field. Set both via JS:

```javascript
document.querySelector('input[name="user[email]"]').value = 'john.employee@example.com';
document.querySelector('input[name="user[oim_id]"]').value = 'john.employee@example.com';
document.querySelector('input[name="user[password]"]').value = 'Password1!';
document.querySelector('input[name="user[password_confirmation]"]').value = 'Password1!';
```

### Waiting for Turbolinks navigation
After clicking a link or submit button, Turbolinks updates the DOM asynchronously.
Always wait for the expected next-page content before asserting or interacting:

```
browser_wait_for("Expected text on next page")
```

Or use `browser_snapshot()` — it implicitly waits for DOM stability.

### Security questions flow
The sequence is always: Question 1 → Question 2 → Question 3. Use `browser_select_option` or
`browser_fill_form` with the select ref, then the answer text ref. Answers used in QA seeds:
- City born: **Boston**
- First pet: **Fluffy**
- First car: **Toyota**

---

## Employer Enrollment Flow — State Sequence

Understanding the full state chain saves debugging time:

```
Employer creates account
  └─> Profile: unsubmitted attestation (MUST approve before publishing)
      └─> Add plan year (BenefitApplication: draft)
          └─> Add benefit package (BenefitPackage with HealthSponsoredBenefit)
              └─> Assign all census employees to package (BenefitGroupAssignment)
                  └─> approve_application! → :approved
                      └─> begin_open_enrollment! → :enrollment_open  ("Enrolling")
```

### Plan year state transitions (BenefitApplication)
```ruby
app.approve_application!       # :draft → :approved
app.begin_open_enrollment!     # :approved → :enrollment_open
# Or bypass to force publish:
app.update_attribute(:aasm_state, :enrollment_open)
```

### Employer attestation state transitions
```ruby
# Must go through submitted → approved (two steps via AASM)
att.submit!   # unsubmitted → submitted
att.approve!  # submitted → approved
# OR bypass:
att.update_attribute(:aasm_state, "approved")
```

---

## Employee Enrollment Flow — State Sequence

```
Employee signs up (/users/sign_up)
  └─> Security questions (3)
      └─> Privacy consent
          └─> Employee search (SSN + DOB must match census_employee)
              └─> Employer match confirmation
                  └─> Contact info
                      └─> Household review
                          └─> Member selection
                              └─> Plan shopping
                                  └─> Enrollment confirmation
```

**Prerequisites for employee search to find a match:**
- `CensusEmployee` with matching `encrypted_ssn` and `dob`
- `CensusEmployee.aasm_state` must be `eligible` (not terminated)
- `CensusEmployee.created_at` must be ≤ `hired_on` (for new hire period to be valid)
- Active `BenefitGroupAssignment` must exist on the census employee

---

## Reusable Seed Scripts (`.aidocs/seeds/`)

| Script | What it creates | When to use |
|---|---|---|
| `helpers.rb` | Shared utilities (require this first) | Always |
| `employer_ready.rb` | Employer org + approved attestation + zip 01247 + staff user | Start of any employer flow |
| `plan_year_published.rb` | Published plan year + benefit package + BGAs on all employees | Before employee enrollment |
| `census_employee_enrollable.rb` | Census employee with backdated created_at + BGA | Before employee match/enrollment |

Run order for full E2E:
```bash
rails runner .aidocs/seeds/employer_ready.rb > /tmp/employer.json
rails runner .aidocs/seeds/plan_year_published.rb > /tmp/plan_year.json
rails runner .aidocs/seeds/census_employee_enrollable.rb > /tmp/employee.json
```

---

## Common Test Credentials

| Role | Email | Password |
|---|---|---|
| HBX Admin | hbxadmin_qa@example.com | aA1!aA1!aA1! |
| Employer (rehire test) | employer_rehire_qa@example.com | aA1!aA1!aA1! |
| Employer (E2E) | employer_qa@example.com | aA1!aA1!aA1! |
| Employee (E2E) | john.employee@example.com | Password1! |

Password rules: min 8 chars, 1 upper, 1 lower, 1 digit, 1 special.

---

## Common URLs

| Page | URL |
|---|---|
| HBX Admin portal | `/exchanges/hbx_profiles` |
| Employer registration | `/benefit_sponsors/profiles/registrations/new?profile_type=benefit_sponsor` |
| Employee privacy/start | `/insured/employee/privacy` |
| Employee signup | `/users/sign_up` |
| Broker registration | `/benefit_sponsors/profiles/registrations/new?profile_type=broker_agency` |
