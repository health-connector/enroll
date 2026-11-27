# Security Policy

## Vulnerability Mitigations

### CodeQL: DOM-based XSS via jQuery `.html()` — May 2026

**Vulnerability:**

CodeQL flagged DOM-based cross-site scripting (XSS) patterns where values read from the DOM via jQuery (`.text()`, `.val()`, `.attr()`) were written back into the DOM via `.html()`, which does not escape HTML entities. The affected locations were:

- `app/views/exchanges/hbx_profiles/_view_hbx_enrollments.html.erb` — reinstate enrollment modal warning messages
- `app/assets/javascripts/quotes/page_actions.js` — slider percentage labels
- `components/sponsored_benefits/app/assets/javascripts/sponsored_benefits/plan_design_proposals.js` — slider percentage labels

An additional finding flagged `app/assets/javascripts/employee_dependent.js`, where a DOM attribute value was used as a jQuery selector without format validation.

**Mitigation:**

All findings were remediated without functional impact. In each affected location, content written was plain text; `.text()` is semantically equivalent to `.html()` for plain text and auto-escapes HTML entities. No in-source suppression comments were added. Low-risk false-positive findings are documented here as accepted risk.

**Actions Taken:**

1. Replaced `.html(...)` with `.text(...)` in the three files listed above.
2. Hardened the `data-target` selector in `app/assets/javascripts/employee_dependent.js`: switched from `.attr("data-target")` to `.data("target")` and added a strict CSS ID format check (`/^#[A-Za-z][A-Za-z0-9_:\-\.]*$/`) before passing the value to `$(selector).remove()`.
3. Remaining CodeQL findings in admin- and broker-only views were assessed as low-risk false positives due to constrained numeric slider sources and restricted access surfaces. These are not suppressed but are documented here as accepted risk.

**Ongoing Measures:**

1. Prefer `.text()` over `.html()` for all plain text updates (enforce via code review).
2. Require explicit justification when `.html()` is introduced with dynamic values.
3. Periodically audit admin/broker-only endpoints for XSS — restricted access does not eliminate risk.
4. Keep legacy/unmounted components out of active asset/runtime paths.

### CodeQL: rb/clear-text-storage-of-sensitive-data — script/policies_for_simulated_renewals.rb

**Vulnerability:**

CodeQL flagged clear-text storage of sensitive information in `script/policies_for_simulated_renewals.rb`, where enrollment HBX IDs are written to plain-text output files.

**Mitigation:**

This finding is considered a false positive in the context of the application's operational constraints:

1. **Data Classification:** Enrollment HBX IDs are internal identifiers, not directly identifying information (SSN, name, contact details).
2. **Scope Restriction:** Script execution is constrained to non-production environments only via `ENV_NAME` guard.
3. **Lifetime:** Output files are short-lived (consumed immediately by `write_enrollment_files.rb`).
4. **Access Control:** Files are created with owner-only permissions (mode `0600`).

**Actions Taken:**

1. Output files created with `0600` permissions, restricting read/write access to file owner.
2. `ENV_NAME` environment guard prevents execution in production; raises exception if `ENV_NAME` is `prod` or `production`.
3. CodeQL suppression comments added at enrollment ID write lines documenting risk assessment rationale.

**Ongoing Measures:**

1. Monitor for changes to CodeQL rule definitions that may require re-assessment.
2. Document renewal workflow dependencies to ensure lower-environment-only execution remains enforced.

Encrypting the output files (with a key such as `SIM_RENEWALS_ENCRYPTION_KEY` managed in lower environments) was considered and not adopted. Given the limited scope, short-lived nature of the data, and existing file permission controls, the simpler approach is appropriate and sufficient for the risk level presented.

**Status:** False positive - Risk adequately mitigated through file permissions and operational controls.


### Mongoid Dynamic Attributes Reduction — June 2026

**Vulnerability:**

Use of `Mongoid::Attributes::Dynamic` allows undeclared fields to be persisted to MongoDB documents. This can introduce schema drift, allow accidental persistence of unexpected attributes, and reduce confidence in model-level validation and data integrity controls.

**Mitigation:**

Removed `Mongoid::Attributes::Dynamic` from non-essential models and retained it only in high-risk legacy surfaces pending targeted audits.

**Actions Taken:**

1. Removed `Mongoid::Attributes::Dynamic` from non-essential models (`ConsumerRole`, `ResidentRole`, `LawfulPresenceDetermination`, `Document`, and matching dummy/spec models).
2. Kept `Mongoid::Attributes::Dynamic` temporarily in `Person`.
3. Kept `Mongoid::Attributes::Dynamic` temporarily in `BenefitSponsors::SponsoredBenefits::SponsorContribution`.
4. Documented both exceptions and risk rationale in this policy.

**Rationale for exceptions:**

- `Person` is a high-traffic legacy model with broad integration surface where immediate strict-field enforcement carries elevated regression risk.
- `SponsorContribution` currently relies on dynamic attribute behavior/inheritance patterns and requires a separate field-definition audit before safe removal.

**Ongoing Measures:**

1. Audit persisted attributes for `Person` and `BenefitSponsors::SponsoredBenefits::SponsorContribution`.
2. Add explicit `field` definitions where required.
3. Remove `Mongoid::Attributes::Dynamic` from the two remaining models after compatibility validation.

### CKEditor 4.2.4 Bundler Audit Findings — August 2026

**Vulnerability:**

`bundler-audit` flags 14 advisories against `ckeditor` 4.2.4, all cross-site scripting (XSS) or content-filtering bypass issues in CKEditor 4's HTML/paste processing, plus one denial-of-service (ReDoS) advisory:

- CVE-2020-27193 / GHSA-4m44-5j2g-xf64
- CVE-2020-9281 / GHSA-vcjf-mgcg-jxjq
- CVE-2021-26271 / GHSA-f6rf-9m92-x2hh (ReDoS in dialog plugin)
- CVE-2021-26272 / GHSA-wpvm-wqr4-p7cw
- CVE-2021-32809 / GHSA-7889-rm5j-hpgg
- CVE-2021-37695 / GHSA-m94c-37g6-cjhc
- CVE-2021-41164 / GHSA-pvmx-g8h5-cprj
- CVE-2021-41165 / GHSA-7h26-63m7-qhf2
- CVE-2022-24728 / GHSA-4fc4-4p5g-6w89
- CVE-2023-4771 / GHSA-wh5w-82f3-wrxh
- CVE-2024-24815 / GHSA-fq6h-4g8v-qqvm
- CVE-2024-24816 / GHSA-mw2c-vx6j-mg76
- CVE-2024-43407 / GHSA-7r32-vfj5-c2jv
- CVE-2024-43411 / GHSA-6v96-m24v-f58j

Several of these (2024 CVEs) have no available CKEditor 4.x patch at all — the `bundler-audit` solution for them is literally "remove or disable this gem until a patch is available." The only real fix for the full set is CKEditor 5 (`>= 5.1.2`), which is a major-version rewrite of the editor (different JS bundling/plugin model, different Rails helper API), not a version bump.

**Exploitability in this application:**

`ckeditor` is wired into a single feature: the `notifier` component's notice-template editor (`components/notifier/app/views/notifier/notice_kinds/_form.html.erb`, via the `cktext_area` helper). Every action on `Notifier::NoticeKindsController` is gated by `authorize ::Notifier::NoticeKind` (Pundit), so this editor is reachable only by staff/admin accounts already authorized to manage notice templates — it is not exposed to the public or to unauthenticated/untrusted end users. These CVEs are almost all "malicious HTML/paste content renders as script inside the editor" bypasses; exploiting them here would require an already-authorized admin account to paste or author crafted content that then executes against another admin viewing/editing the same template — a much narrower blast radius than the CVEs' public/anonymous-input CVSS ratings assume.

**Mitigation:**

Given no non-breaking patch exists and the exposure is limited to a trusted, Pundit-authorized staff workflow, we are documenting and ignoring these findings rather than attempting the CKEditor 5 migration as part of routine security-check remediation. The migration is being tracked separately as its own initiative given the scope (editor API rewrite, JS asset changes, and full regression testing of the notifier template-authoring UI).

**Actions Taken:**

1. Documented this issue and the mitigation rationale.
2. Added all 14 CVE identifiers to `.bundler-audit.yml`'s ignore list.
3. Opened a follow-up ticket to scope and schedule the CKEditor 5 migration.

**Ongoing Measures:**

1. Track the CKEditor 5 migration as a standalone initiative.
2. Re-run `bundler-audit` after the migration lands to confirm these entries can be removed from the ignore list.
3. Periodically re-check for a compatible CKEditor 4.x patch release that would allow closing individual advisories sooner.

### GHSA-42qh-8mx8-7wqm - rack-proxy HTTP response smuggling via ambiguous backend framing

**Vulnerability:** rack-proxy below `1.0.3` can forward an incorrect `Content-Length` when a backend response carries both `Transfer-Encoding` and `Content-Length`, letting a malicious or compromised backend desynchronize a persistent downstream connection. Upstream confirmed 1.0.0-1.0.2 as affected and did not assess pre-1.0 releases; bundler-audit flags our `0.7.7`.

**Current Status:** `rack-proxy` is not a direct dependency. It is pulled in only by `shakapacker` 9.6.1 (npm package 9.5.0) (root lockfile). It cannot be bumped on its own: since rack-proxy 1.0, a proxy with no explicit backend returns 502 by default, and shakapacker 9.x's `DevServerProxy` never supplies one, so every asset request proxied to the local dev server would fail. The compatibility fix shipped only in shakapacker 10.3.1 (shakacode/shakapacker#1222); there is no 9.x backport.

**Exploitability:** Shakapacker mounts `DevServerProxy` only when `dev_server` is configured, and `config/shakapacker.yml` defines `dev_server` only under `development`. The proxy is not in the middleware stack in test, staging, or production, which serve precompiled assets. In development it forwards only `/packs/*` requests, only while `bin/shakapacker-dev-server` is running, and only to that local webpack dev server, a trusted backend running our own code. The attack requires an attacker-controlled backend, which does not exist in any environment.

**Mitigation:** Added `GHSA-42qh-8mx8-7wqm` to `.bundler-audit.yml` until shakapacker is upgraded to `>= 10.3.1`, which works with rack-proxy `>= 1.0.3`.

**Actions Taken:**
1. Documented the vulnerability, exploitability, and exit plan in this file.
2. Added `GHSA-42qh-8mx8-7wqm` to the bundler-audit ignore list.
3. Tracked the shakapacker 10.3.1 upgrade as a separate ticket.

**Ongoing Measures:**
1. Remove the ignore entry and bump rack-proxy when the shakapacker upgrade lands.
2. Revisit sooner if `dev_server` is added to a non-development environment in `config/shakapacker.yml`, or if another gem starts depending on `rack-proxy`.

### Bearer: sensitive data in report CSV files (CWE-313) — November 2026

**Vulnerability:**

Bearer's `ruby_lang_file_generation` rule flags 16 CSV writes in manually run report tasks and scripts that write personal data (names, emails, HBX IDs) to files in clear text. Two of them, `ivl_non_dc_address.rake` and `lawful_alien_docs.rake`, also write SSN and date of birth.

- `script/ea_access_list.rb` (5 rows)
- `lib/tasks/EE_autorenew_data_clean_up.rake`
- `lib/tasks/outstanding_dc_residency_report.rake`
- `lib/tasks/hbx_reports/census_ee_enrollments_with_invalid_hbx_members.rake`
- `lib/tasks/hbx_reports/employee_termination_submitted_on_report.rake`
- `lib/tasks/hbx_reports/ivl_non_dc_address.rake`
- `lib/tasks/hbx_reports/ivl_termination_submitted_on_report.rake`
- `lib/tasks/hbx_reports/lawful_alien_docs.rake` (2 rows)
- `lib/tasks/hbx_reports/test_employer_group_enrollment_data.rake`
- `lib/tasks/hbx_reports/users_account_with_no_email.rake`
- `lib/tasks/hbx_reports/waiver_not_cancelling_passive_renewal_enrollment.rake`

**Mitigation:**

These are accepted risks, not false positives: each task exists to produce a report containing this data, and the output files are handled by the operators who run them. Bearer's detections are accurate.

**Actions Taken:**

1. Kept the existing `bearer.ignore` entries for these rows and added the 16 that were missing. Bearer fingerprints are positional (`<hash>_<index>`, numbered in line order per rule and file), each row can have several, and Bearer reports the lowest one not ignored. The earlier entries lacked each row's first fingerprint, so all 16 rows stayed open in code scanning despite the earlier triage.
2. The new entries are marked `false_positive: false` (accepted risk). Older entries for the same rows keep `false_positive: true` from the earlier triage.
3. All rows except `script/ea_access_list.rb:21` were previously accepted through `bearer.ignore` (June 2025 and August 2026). Line 21, the "No person record" row, is accepted here for the first time on the same rationale.

**Ongoing Measures:**

1. Every fingerprint index in these 11 files is now ignored. A new finding added above an existing row takes an ignored fingerprint and is not reported, and an already-accepted row resurfaces under a new index instead. Treat a resurfaced finding in these files as a sign of new code and review the file's history before ignoring anything else.
2. Re-check these entries after a Bearer upgrade or any edit to these files, since either can renumber the fingerprints.
