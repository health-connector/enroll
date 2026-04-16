# Brakeman Security Findings Report

**Generated:** 2026-04-15
**Branch scanned:** `master`
**Tool:** Brakeman 8.0.4
**Filter:** `is:open branch:master tool:Brakeman`
**Total active warnings:** 4 across 3 check types
**Ignored warnings:** 12 (see [Ignored Warnings](#ignored-warnings))

> **Note:** Brakeman's SARIF output is uploaded to GitHub Actions artifacts rather than to GitHub Code Scanning. Findings were retrieved from the `brakeman-text-report` and `brakeman-json-report` artifacts of the `security-code-scan-daily.yml` workflow run on 2026-04-15.

---

## Summary

| Group | Check | Severity | Confidence | Alerts | Resolution |
|---|---|---|---|---|---|
| [A](#group-a--dangerous-eval-in-notice-builder) | `Evaluation` | High | High | 1 | Open questions — see below |
| [B](#group-b--xss-unescaped-parameter-in-coverage-reports) | `CrossSiteScripting` | Medium | Weak | 1 | Likely false positive — needs confirmation |
| [C](#group-c--xss-model-attribute-in-link_to-href) | `LinkToHref` | Medium | Weak | 1 | Likely false positive — needs confirmation |
| [D](#group-d--marshal-load-on-file-path) | `Deserialize` | Medium | Weak | 1 | Likely false positive — script context only |

---

## Group A — Dangerous Eval in Notice Builder

**Check:** `Evaluation`
**Confidence:** High
**File:** `components/notifier/app/models/notifier/notice_builder.rb:36`

### What Brakeman found

`instance_eval` is called on a string derived from a database-stored model attribute:

```ruby
# notice_builder.rb lines 26–36
template.data_elements.each do |element|
  elements = element.split('.')
  date_element = elements.detect{|ele| Notifier::MergeDataModels::EmployerProfile::DATE_ELEMENTS.any?{|date| ele.match(/#{date}/i).present?}}

  if date_element.present?
    date_ele_index = elements.index(date_element)
    elements = elements[0..date_ele_index]
    elements[date_ele_index] = date_element.scan(/[a-zA-Z_]+/).first
  end
  element_retriver = elements.reject{|ele| ele == recipient_klass_name.to_s}.join('_')
  builder.instance_eval(element_retriver)
end
```

`template.data_elements` is a Mongoid `Array` field defined in the `Template` model (set by staff via the notice configuration panel). Each element string is split on `.`, filtered, joined with `_`, and then passed to `instance_eval` on the builder instance.

### Why this is flagged High confidence

`instance_eval` executes arbitrary Ruby code in the context of the receiver object. Even though `data_elements` is DB-stored (not directly from a web request), this pattern means:

- Any user or admin with write access to notice templates in the admin UI could inject a string like `system('curl ...')` as a data element
- There is no allowlist validation on data element values before they are evaluated
- The builder pattern is also used in the `construct_notice_object` method (line 20), which uses `constantize` on `recipient` — also DB-stored — making this a two-vector pattern

### Open Questions

1. **Who has write access to notice templates (`NoticeKind`/`Template`) via the admin UI?**
   If only trusted HBX staff with privileged admin roles can modify notice templates, the attack surface is constrained (insider threat only). If brokers or employers can influence notice template data elements, this is a more serious exposure.

2. **Is there an existing allowlist or validation on `data_elements` entries?**
   Check whether `Template` or `NoticeKind` has any model-level validation that restricts `data_elements` values to known dot-notation attribute paths (e.g., matching a regex like `/\A[a-zA-Z_.]+\z/`).

3. **Is there an alternative to `instance_eval` that would accomplish the same data lookup?**
   The apparent intent is to resolve a dotted attribute path (e.g., `"employer_profile.legal_name"`) against the builder object. This could be done safely with `Object#public_send` chains rather than `instance_eval`.

### Recommended Path

- **Short-term:** Add model validation on `Template#data_elements` entries to only accept strings matching a safe attribute-path pattern (e.g., `[a-zA-Z0-9_.]+`)
- **Long-term:** Replace `instance_eval(element_retriver)` with a safe attribute-path resolver using `public_send` traversal, which cannot execute arbitrary code:

```ruby
# Safe alternative: resolve a dot-path like "employer_profile.legal_name"
def resolve_path(object, path)
  path.split('.').reduce(object) { |obj, method| obj.public_send(method) }
end
```

---

## Group B — XSS: Unescaped Parameter in Coverage Reports

**Check:** `CrossSiteScripting`
**Confidence:** Weak
**File:** `components/benefit_sponsors/app/views/benefit_sponsors/profiles/employers/employer_profiles/_coverage_reports.html.erb:8`

### What Brakeman found

The datatable rendered on line 8 is output via `raw`, and the `@datatable` object was constructed (in the controller) with user-supplied request parameters:

```erb
<%= raw render_datatable(@datatable, { sDom: "...", ... }) %>
```

Brakeman traces the data flow from `params.require(:employer_profile_id)` and `params[:billing_date]` through the `BenefitSponsorsCoverageReportsDataTable` object to the `raw` output call, flagging the lack of escaping.

### Assessment

This is likely a **false positive** for the following reasons:

- `params[:employer_profile_id]` is validated by `BSON::ObjectId.from_string(...)` at the query level — a non-hex-string value raises an exception before reaching the view
- `params[:billing_date]` is parsed by `DateParser.smart_parse(...)` which converts it to a `Date` object — the raw string never reaches the HTML output
- `render_datatable` from the `effective_datatables` gem generates its own HTML structure from the datatable configuration options; it does not interpolate param values directly into HTML output

The use of `raw` here is to allow the gem to output HTML markup (tables, pagination controls) — this is the intended usage pattern for `effective_datatables`.

### Recommended Confirmation

- Verify that `BenefitSponsorsCoverageReportsDataTable` does not reflect `params[:employer_profile_id]` or `params[:billing_date]` directly into any HTML attribute or cell content without escaping
- If confirmed clean, this alert can be documented as a false positive in `brakeman.ignore`

---

## Group C — XSS: Model Attribute in `link_to` Href

**Check:** `LinkToHref`
**Confidence:** Weak
**File:** `components/benefit_sponsors/app/views/benefit_sponsors/profiles/employers/employer_profiles/my_account/accounts/_pay_online_confirmation_modal.html.erb:14`

### What Brakeman found

A `link_to` call uses `@wf_url` as its href:

```erb
<%= link_to l10n('pay_online'),
      @wf_url,
      class: 'btn btn-default pay_online_confirmation pull-right left-margin',
      target: '_blank',
      rel: 'noopener noreferrer' %>
```

Brakeman flags `link_to` calls whose href comes from a model attribute because a value like `javascript:alert(1)` in the href would execute JavaScript when clicked. The flagged code snapshot in the scan artifact shows the full `WellsFargo::BillPay::SingleSignOn.new(...)` expression — reflecting an earlier version of the view where the SSO URL was computed inline rather than in the controller.

### Current Code

The current view uses `@wf_url`, which is set in the private `wells_fargo_sso` method of the controller:

```ruby
# employer_profiles_controller.rb lines 190–198
wells_fargo_sso = ::WellsFargo::BillPay::SingleSignOn.new(
  @employer_profile.hbx_id,
  @employer_profile.hbx_id,
  @employer_profile.dba.presence || @employer_profile.legal_name,
  email
)
@wf_url = wells_fargo_sso.url if wells_fargo_sso.present? && wells_fargo_sso.token.present?
```

The URL is generated by the SSO library from employer profile fields — it is not directly user-controllable from a web request.

### Assessment

This is likely a **false positive or low practical risk**:

- The URL comes from a server-side SSO library, not from raw user input
- The employer profile fields (`hbx_id`, `dba`, `legal_name`) are set by the enrollment system, not by the employer user via a free-text form field
- `link_to` in Rails HTML-escapes the href attribute by default, preventing classic HTML injection; only a `javascript:` scheme would bypass this and that would require `hbx_id` or a similar field to contain `javascript:`, which is not possible via normal enrollment flows

### Recommended Confirmation

- Check whether `WellsFargo::BillPay::SingleSignOn#url` validates or encodes the values passed to it (it should for a financial SSO integration)
- If the URL is confirmed to always be an `https://` URL, this can be documented as a false positive in `brakeman.ignore`

---

## Group D — Marshal.load on File Path

**Check:** `Deserialize`
**Confidence:** Weak
**File:** `lib/transcript_generator.rb:180`

### What Brakeman found

`Marshal.load` is called on a file handle:

```ruby
# transcript_generator.rb lines 173–180
Dir.glob("#{TRANSCRIPT_PATH}/*.bin").each do |file_path|
  # ...
  person_importer.transcript = Marshal.load(File.open(file_path))
```

`Marshal.load` can execute arbitrary Ruby code if given a maliciously crafted binary — this is a well-known deserialization risk in Ruby. Brakeman flags all `Marshal.load` calls regardless of context.

### Assessment

This is likely a **false positive** in the web application security context:

- `TRANSCRIPT_PATH` is a hardcoded constant: `"#{Rails.root}/person_transcripts"` (line 8)
- The `.bin` files are glob-matched from a local server directory, not from user-uploaded content or a network source
- `TranscriptGenerator` is a command-line utility script, not a web controller — it is invoked manually by operations staff, not via an HTTP request
- For `Marshal.load` to be exploited here, an attacker would need filesystem write access to `Rails.root/person_transcripts/` first, at which point they have more direct attack vectors anyway

### Recommended Path

- **If this script is actively used against production data**, consider replacing `Marshal` serialization with a safer format (JSON or MessagePack) for the transcript binary files. This would also eliminate the "file access" warning #809 in the ignored list
- **If this script is dormant or only run in development**, document it as a false positive in `brakeman.ignore`
- Note: the comment on line 177 (`# rows = Transcripts::ComparisonResult.new(Marshal.load(...))`) suggests the original design has already been partially refactored — it may be worth evaluating whether the `Marshal.load` path is still needed at all

---

## Ignored Warnings

The following 12 warnings are currently suppressed in `brakeman.ignore`. Several have no associated notes explaining the rationale for ignoring.

| # | Check | File | Line | Message | Note |
|---|---|---|---|---|---|
| 1 | `Execute` (Command Injection) | `app/data_migrations/cancel_plan_years_group.rb:24` | 24 | Possible command injection | *(none)* |
| 2 | `MassAssignment` | `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/registrations_controller.rb` | 111 | `permit!` allows any keys | *(none)* |
| 3 | `MassAssignment` | `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/registrations_controller.rb` | 115 | `permit!` allows any keys | *(none)* |
| 4 | `MassAssignment` | `app/controllers/exchanges/broker_applicants_controller.rb` | 48 | `permit!` allows any keys | *(none)* |
| 5 | `MassAssignment` | `app/controllers/exchanges/broker_applicants_controller.rb` | 57 | `permit!` allows any keys | *(none)* |
| 6 | `MassAssignment` | `app/controllers/exchanges/broker_applicants_controller.rb` | 62 | `permit!` allows any keys | *(none)* |
| 7 | `MassAssignment` | `app/controllers/users_controller.rb` | 6 | `permit!` allows any keys | *(none)* |
| 8 | `FileAccess` | `lib/transcript_generator.rb` | 46 | Model attribute used in file name | *(none)* |
| 9 | `SendFile` | `components/notifier/app/controllers/notifier/notice_kinds_controller.rb` | 74 | Model attribute used in file name | *(none)* |
| 10 | `SendFile` | `app/controllers/employers/employer_profiles_controller.rb` | 226 | Model attribute used in file name | *(none)* |
| 11 | `CrossSiteScripting` | `app/views/exchanges/hbx_profiles/_view_enrollment_to_update_end_date.html.erb` | 22 | Unescaped model attribute | *(none)* |
| 12 | `SQL` | `project_gems/effective_datatables-2.6.14/.../active_record_datatable_tool.rb` | 189 | Possible SQL injection | *(none)* |

### Recommendations for Ignored Entries

1. **Add rationale notes** to all 12 entries — `brakeman.ignore` supports a `note` field. Without notes, future reviewers cannot distinguish deliberate ignores from forgotten ones.

2. **The `MassAssignment` ignores (#2–#7) are worth revisiting.** `permit!` is a blanket override that allows every parameter key, bypassing Rails' strong parameters protection. Each should be replaced with an explicit allowlist (e.g., `permit(:first_name, :last_name, :email)`) or documented with a concrete reason why `permit!` is safe at that call site.

3. **The SQL injection ignore (#12) is in a vendored gem** (`project_gems/effective_datatables-2.6.14`). This gem version is pinned locally — check if a patched version is available upstream, or if the affected code path is reachable from user input in the application context.

4. **The `Obsolete` entries** — the scan reported 19 fingerprints in `brakeman.ignore` that no longer match any warning in the codebase. These should be pruned from the ignore file to keep it clean.

---

## Remediation Priority Order

| Priority | Group | Action | Effort |
|---|---|---|---|
| **1 — Investigate** | A | Audit who can write `NoticeKind`/`Template` data_elements; add allowlist validation on element values | Research + small fix |
| **2 — Replace long-term** | A | Replace `instance_eval` with `public_send`-based path resolver | Medium refactor |
| **3 — Add notes** | Ignored | Add `note` fields to all 12 entries in `brakeman.ignore` explaining the rationale | Low effort |
| **4 — Clean up** | Ignored | Remove 19 obsolete fingerprints from `brakeman.ignore` | Low effort |
| **5 — Refactor** | Ignored | Replace `permit!` with explicit allowlists in the 5 controller locations | Medium effort |
| **6 — Confirm false positive** | B, C, D | Verify assessment and add notes to `brakeman.ignore` | Research only |

## Open Items Tracking

- [ ] **Group A:** Determine what roles have write access to notice template `data_elements` in the admin UI
- [ ] **Group A:** Check whether any validation exists on `Template#data_elements` entries
- [ ] **Group A:** Evaluate refactoring `instance_eval(element_retriver)` to a `public_send` chain
- [ ] **Group B:** Verify `BenefitSponsorsCoverageReportsDataTable` does not reflect param values into raw HTML output; add `brakeman.ignore` note if confirmed clean
- [ ] **Group C:** Verify `WellsFargo::BillPay::SingleSignOn#url` always returns an `https://` URL; add `brakeman.ignore` note if confirmed
- [ ] **Group D:** Determine if `TranscriptGenerator` is still actively run against production data; either replace `Marshal` or add `brakeman.ignore` note
- [ ] **Ignored:** Add rationale `note` fields to all 12 suppressed entries
- [ ] **Ignored:** Prune 19 obsolete fingerprints from `brakeman.ignore`
- [ ] **Ignored:** Review `permit!` usage in `registrations_controller.rb`, `broker_applicants_controller.rb`, and `users_controller.rb`
