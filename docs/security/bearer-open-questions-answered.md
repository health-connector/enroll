# Bearer open questions — code-backed answers

This document records factual answers from the Enroll codebase (as of the research commit at authoring time). It is intended to support refinement of `bearer-findings-report.md`.

---

## 1. `ux-plan-filter_controller.js`: `productArray` and `p.title`

### Where `productArray` comes from

Inside `showFilteredPlans`, `productArray` is a new array; each element of the `products` argument is pushed into it. The `products` argument is supplied by `sortPlans()` as `avalilableProducts`, which is produced by:

`JSON.parse(filteredDiv.dataset.availableProduct)`

So the intended source is the DOM: the `#filteredPlans` element’s `data-available-product` attribute (Stimulus/`dataset` exposes this as `availableProduct`).

Relevant code: `app/javascript/ui_components/controllers/ux-plan-filter_controller.js` (`sortPlans`, `showFilteredPlans`).

### Relation to plan shopping pages in this repo

Plan shopping views (for example `app/views/insured/plan_shoppings/show.html.slim`) define `#filteredPlans` with `data-enrollments` and use inline JavaScript that parses enrollment JSON from that attribute—not `data-available-product`. A repository search does not show any template setting `data-available-product` (or the other attributes this Stimulus controller reads: `data-members`, `data-group-enrollment`, `data-plan-carrier`) on `#filteredPlans`. The Stimulus controller identifier also does not appear outside this file and the security report. So in the current tree, this controller is not visibly wired to an HTML page the way plan shopping is.

### If `title` were present in that JSON

Each entry is parsed again as JSON (`JSON.parse(p)`), and `title` is read from the resulting object. In the **actually used** plan shopping path, comparable display/sort data comes from server-built JSON via `json_for_plan_shopping_member_groups`, which builds hashes from `member_group.group_enrollment.to_json` and merges `issuer_name` from the product’s issuer profile—not from an end-user “plan name” text field in the helper.

Relevant helper: `app/helpers/application_helper.rb` — `json_for_plan_shopping_member_groups`.

---

## 2. Agent mailbox message body rendering

Agent inbox **message detail** uses `app/views/exchanges/agents/_message.html.erb`. Both **subject** and **body** are rendered with `sanitize(...)`:

- Subject: `sanitize(message.try(:subject))`
- Body (labeled “Content”): `sanitize(message.try(:body))`

They are **not** rendered with `raw` or `.html_safe` in that partial.

The AJAX show action loads that partial via `app/views/exchanges/agents_inboxes/show.js.erb` (`render "exchanges/agents/message", message: @message`).

The **list** row partial `app/views/exchanges/agents/_individual_message.html.erb` uses `sanitize` on the subject only; the body is not shown in the list (only a “show” link).

For comparison, the generic shared partial `app/views/shared/inboxes/_message.html.erb` (used in some other inbox flows) also uses `sanitize` on subject and body.

---

## 3. Benefit Sponsors / family members: controller inventory

- **`BenefitSponsors::Profiles::RegistrationsController`**: `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/registrations_controller.rb`
- **`BenefitSponsors::Profiles::Employers::EmployerStaffRolesController`**: `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/employers/employer_staff_roles_controller.rb`
- **`family_members_controller`**: There is **no** `family_members_controller` under `components/benefit_sponsors`. Dependent/family-member HTTP handling for insured flows lives in **`Insured::FamilyMembersController`** (`app/controllers/insured/family_members_controller.rb`). **`IndividualMarket::FamilyMembersController`** (`app/controllers/individual_market/family_members_controller.rb`) only implements resident index/new/edit/show-style actions and does **not** define `create`/`update`/`destroy` for `params[:dependent]`.

The sections below give the same level of detail for registrations, family members (insured), and employer staff roles.

---

## 4. `BenefitSponsors::Profiles::RegistrationsController` — parameters and intended form fields

### Strong parameters behavior

- **`registration_params`** (used by `create` and `update`):
  - Merges into `params[:agency]`: `:profile_id` from `params["id"]`, and `:current_user_id` from the signed-in user when present.
  - Calls **`params[:agency].permit!`**, which permits all keys under `agency` at the ActionController layer.

There is also an **`organization_params`** method that does `params[:agency][:organization].permit!`; it is **not** referenced by this controller’s actions in the same file (dead code from the perspective of this class).

### Form object boundary

Input is passed to **`BenefitSponsors::Organizations::OrganizationForms::RegistrationForm`**, which uses Virtus attributes including:

- Top-level: `current_user_id`, `profile_type`, `portal`, `profile_id`, `contact_information`, `staff_roles`, `organization`.
- Nested **`organization`** (`OrganizationForms::OrganizationForm`): `fein`, `legal_name`, `dba`, `entity_kind`, `entity_kind_options`, `profile_type`, nested **`profile`** (`ProfileForm`).
- Nested **`profile`** (`OrganizationForms::ProfileForm`): includes `id`, `market_kind`, `is_benefit_sponsorship_eligible`, `corporate_npn`, `languages_spoken`, `working_hours`, `accept_new_clients`, `home_page`, `contact_method`, `sic_code`, ACH fields (`ach_account_number`, `ach_routing_number`, `ach_routing_number_confirmation`), `referred_by`, `referred_reason`, nested **`office_locations`**, optional **`inbox`**, etc.
- **`staff_roles`**: array of **`OrganizationForms::StaffRoleForm`** (see section 6 for attribute list).
- Office locations: **`OfficeLocationForm`** with nested **`AddressForm`** (`address_1`, `address_2`, `city`, `state`, `zip`, `kind`, `county`, …) and **`PhoneForm`** (`kind`, `area_code`, `number`, `extension`, …).

### What the registration views actually post (illustrative)

**Employer** (`benefit_sponsors/profiles/registrations/new.html.slim` → `ui-components/v1/forms/employer_registration/_employer_profile_form.html.slim`):

- Under `agency[staff_roles_attributes][]` / `fields_for :staff_roles`: see employer staff role partial — `person_id` (hidden when applicable), `first_name`, `last_name`, `dob`, `email`, `area_code`, `number`, `extension`.
- Under `agency[organization]`: `legal_name`, `dba`, `fein`, `entity_kind` (select).
- Under `agency[organization][profile_attributes]`: `sic_code` (when enabled), `referred_by`, `referred_reason`, `contact_method`, nested office locations (address + phone fields per location), etc.

**Broker** (`broker_registration` partials):

- Staff/personal: `first_name`, `last_name`, `dob`, `email`, `npn`.
- Organization: `legal_name`, `dba`, hidden `entity_kind`.
- Profile: `market_kind`, `languages_spoken` (multi-select), `working_hours`, `accept_new_clients`, office locations, and when feature flags apply, **`ach_account_number`**, **`ach_routing_number`**, **`ach_routing_number_confirmation`** (`benefit_sponsors/shared/profiles/broker_agency/_bank_information.html.erb`).

### Summary

At the controller layer, **`permit!` allows any nested key under `agency`**. The **registration form objects and views** narrow what is **designed** to be submitted to employer/broker registration data (organization, profile, office locations, staff role fields, optional ACH). Extra keys under `agency` still pass through `permit!` into the form initialization path.

---

## 5. `Insured::FamilyMembersController` — parameters and fields that reach persistence

### Actions and param keys

- **`create`**: `Forms::FamilyMember.new(params[:dependent])` — **no** `permit` in the controller; the full `params[:dependent]` hash is passed into the form.
- **`update`**:
  - If the family’s primary applicant has a **resident** role: `@dependent.update_attributes(params.require(:dependent))` — uses **required** `dependent` params **without** going through `dependent_person_params`.
  - Otherwise: `@dependent.update_attributes(dependent_person_params.to_h)` — uses an explicit permit list (below). After a successful update, if a **consumer_role** exists, the code also runs `consumer_role.update_attribute(:is_applying_coverage, params[:dependent][:is_applying_coverage])`.
- **`init_address_for_dependent`** (private): when `@dependent.addresses` is `ActionController::Parameters`, each address is converted with **`address.permit!`** before building `Address` models.

### Explicit permit list (`dependent_person_params` / `person_parameters_list`)

Used on **update** for the non-resident-primary path. Permitted keys include:

- Identity / demographics: `family_id`, `first_name`, `last_name`, `middle_name`, `name_pfx`, `name_sfx`, `dob`, `ssn`, `no_ssn`, `gender`, `relationship`, `language_code`, `is_incarcerated`, `is_disabled`, `is_consumer_role`, `is_resident_role`, `immigration_doc_statuses` (array), `us_citizen`, `naturalized_citizen`, `eligible_immigration_status`, `indian_tribe_member`, `tribal_id`, `tribal_state`, `tribal_name`, `tribe_codes` (array), `same_with_primary`, `no_dc_address`, `no_dc_address_reason`, `is_applying_coverage`, `is_homeless`, `is_temporarily_out_of_state`, `is_moving_to_state`, `user_id`, `dob_check`, `is_tobacco_user`.
- **Addresses**: nested `addresses` with `kind`, `address_1`, `address_2`, `city`, `state`, `zip`, `county`, `id`, `_destroy`.
- **Race / ethnicity**: `allowed_race_or_ethnicity_params` — nested `race` (`other_race`, `attested_races` array) and `ethnicity` (`hispanic_or_latino`, `other_ethnicity`, `attested_ethnicities` array).

### What the form object actually writes to the database (high level)

`Forms::FamilyMember#save` / `extract_person_params` / `assign_person_address` persist **person** attributes such as names, `gender`, `dob`, `ssn` / `no_ssn`, `race`, `ethnicity`, `language_code`, incarceration flag, citizenship-related derived fields, `tribal_id`, DC address flags, **relationship**, and **nested addresses**. Consumer/resident role branches add role-specific setup. VLP document updates run from the controller after save/update when applicable.

### UI-facing fields (dependent form)

`app/views/insured/family_members/_dependent_form.html.erb` includes fields such as `first_name`, `middle_name`, `last_name`, `dob`, `ssn`, `no_ssn`, `gender`, `relationship`, `is_applying_coverage` (via shared partial), consumer fields partial, `same_with_primary`, address fields, hidden `family_id`, plus resident/employee variants.

### Summary

- **`create`** and **resident-primary `update`** use **unfiltered** `params[:dependent]` (beyond `require` on update) at the controller boundary.
- **Consumer/employee `update`** uses **`dependent_person_params`**, a long explicit permit list, plus a separate `update_attribute` on `is_applying_coverage`.

---

## 6. `BenefitSponsors::Profiles::Employers::EmployerStaffRolesController` — parameters and intended fields

### Strong parameters — `staff_params`

- Ensures `params[:staff]` is a hash (empty if missing).
- Merges **`profile_id`** from `params["profile_id"]` or `params["id"]`, and **`person_id`** from `params["person_id"]`.
- Calls **`params[:staff].permit!`**.

### Routes and how params are supplied

Engine routes (`components/benefit_sponsors/config/routes.rb`): `resources :employer_staff_roles` under `profiles/employers`, with **`member { get :approve }`**.

- **`create`**: Form posts to `profiles_employers_employer_staff_roles_path(profile_id: ...)` with **`staff`** fields. The add-staff partial (`employer_staff_roles/_form.html.erb`) exposes **`first_name`**, **`last_name`**, **`dob`** only; `staff_params` still permits any key under `staff`.
- **`approve`**: Example link in `_employer_form.html.erb`: `approve_profiles_employers_employer_staff_role_path(id: @agency.profile_id, person_id: staff.person_id)` — **GET**, so **`staff`** may be empty; **`profile_id`** and **`person_id`** come from route/query via the `merge!` in `staff_params`.
- **`destroy`**: `profiles_employers_employer_staff_role_path(id: @agency.profile_id, person_id: staff.person_id)` with **DELETE** — same pattern.

### Form model attributes (`OrganizationForms::StaffRoleForm`)

Virtus attributes on the form: `npn`, `first_name`, `last_name`, `email`, `phone`, `status`, `dob`, `person_id`, `area_code`, `number`, `extension`, `profile_id`, `profile_type`.

The **employer** add-staff form only submits a subset; **broker** staff registration uses additional fields (e.g. `npn`) in a different flow. **`permit!`** still allows any key under `staff` for these actions.

---

## 7. `IndividualMarket::FamilyMembersController` — scope

This controller defines **`resident_index`**, **`new_resident_dependent`**, **`edit_resident_dependent`**, and **`show_resident_dependent`** only. It does **not** implement actions that accept **`params[:dependent]`** for create/update/destroy. Resident dependent persistence for create/update is handled through **`Insured::FamilyMembersController`** when the primary applicant has a resident role (see section 5).

---

## Code reference index

| Topic | Location |
|--------|----------|
| Stimulus plan filter | `app/javascript/ui_components/controllers/ux-plan-filter_controller.js` |
| Plan shopping enrollment JSON | `app/helpers/application_helper.rb` (`json_for_plan_shopping_member_groups`) |
| Agent message detail | `app/views/exchanges/agents/_message.html.erb` |
| Agent inbox JS show | `app/views/exchanges/agents_inboxes/show.js.erb` |
| Benefit Sponsors registrations | `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/registrations_controller.rb` |
| Registration form models | `components/benefit_sponsors/app/models/benefit_sponsors/organizations/organization_forms/*.rb` |
| Insured family members | `app/controllers/insured/family_members_controller.rb` |
| Family member form object | `app/models/forms/family_member.rb` |
| Employer staff roles | `components/benefit_sponsors/app/controllers/benefit_sponsors/profiles/employers/employer_staff_roles_controller.rb` |
| Individual market family members | `app/controllers/individual_market/family_members_controller.rb` |
