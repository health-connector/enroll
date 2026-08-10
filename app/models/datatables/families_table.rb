# frozen_string_literal: true

module Datatables
  # Table definition for the Families admin datatable. Wraps the filter-tab
  # attributes in Queries::FamilyDatatableQuery and implements the table
  # contract documented in Datatables::FragmentRendering. On SHOP-only sites
  # the Individual Enrolled filter branch and the consumer? column are hidden
  # (individual_market_is_enabled? is false).
  class FamiliesTable
    include Config::AcaModelConcern

    def param_key
      'families'
    end

    # No column is user-sortable; name is the default-ordered column (index 0,
    # asc), so its non-clickable header carries the sort indicator and its tds
    # the sort shading.
    def columns
      cols = [
        { name: 'name',               label: 'Name',                sortable: false, type: :string, ordered: true },
        { name: 'ssn',                label: 'SSN',                 sortable: false, type: :string },
        { name: 'dob',                label: 'DOB',                 sortable: false, type: :string },
        { name: 'hbx_id',             label: 'HBX ID',              sortable: false, type: :integer },
        { name: 'count',              label: 'Count',               sortable: false, type: :string, width: '100px' },
        { name: 'active_enrollments', label: 'Active Enrollments?', sortable: false, type: :string },
        { name: 'registered?',        label: 'Registered?',         sortable: false, type: :string, width: '100px' }
      ]
      cols << { name: 'consumer?', label: 'Consumer?', sortable: false, type: :string, width: '100px' } if individual_market_is_enabled?
      cols << { name: 'employee?', label: 'Employee?', sortable: false, type: :string, width: '100px' }
      cols << { name: 'actions', label: 'Actions', sortable: false, type: :string, width: '50px' }
      cols
    end

    # The query wrapper reads string keys ('families', 'employer_options', ...),
    # while the controller collects the filter attributes with symbol keys.
    def collection(attributes)
      Queries::FamilyDatatableQuery.new(attributes.with_indifferent_access)
    end

    def global_search?
      true
    end

    # The employer_options 'enrolled' and 'waived' scopes are quirks kept from
    # the legacy definition: the query wrapper has no 'enrolled' branch and
    # checks 'coverage_waived' (never emitted), so neither tab narrows the
    # collection.
    def filters
      families_tab = [
        { scope: 'all', label: 'All' },
        { scope: 'by_enrollment_shop_market', label: 'Employer Sponsored Coverage Enrolled', subfilter: :employer_options },
        { scope: 'non_enrolled', label: 'Non Enrolled' }
      ]
      if individual_market_is_enabled?
        families_tab.insert(1, { scope: 'by_enrollment_individual_market', label: 'Individual Enrolled', subfilter: :individual_options })
      end

      {
        employer_options: [
          { scope: 'all', label: 'All' },
          { scope: 'enrolled', label: 'Enrolled' },
          { scope: 'by_enrollment_renewing', label: 'Renewing' },
          { scope: 'waived', label: 'Waived' },
          { scope: 'sep_eligible', label: 'SEP Eligible' }
        ],
        individual_options: [
          { scope: 'all', label: 'All' },
          { scope: 'all_assistance_receiving', label: 'Assisted' },
          { scope: 'all_unassisted', label: 'Unassisted' },
          { scope: 'sep_eligible', label: 'SEP Eligible' }
        ],
        families: families_tab,
        top_scope: :families
      }
    end

    def filter_scopes
      [:families, :employer_options, :individual_options]
    end

    def date_filter
      nil
    end

    def default_order_column
      'name'
    end

    def column_index_offset
      0
    end

    def bulk_actions
      []
    end

    def disable_selectric?
      false
    end

    def buttons
      %w[csv excel]
    end

    def per_page_options
      [10, 25, 50, 100]
    end

    # The actions column is excluded from the export.
    def csv_headers
      columns[0..-2].map { |col| col[:label] }
    end

    def csv_row(row)
      person = row.primary_applicant.person
      values = [
        person.full_name,
        helpers.truncate(helpers.number_to_obscured_ssn(person.ssn)),
        helpers.format_date(person.dob),
        person.hbx_id,
        row.active_family_members.size,
        row.active_household.hbx_enrollments.non_external.active.enrolled_and_renewing.present? ? 'Yes' : 'No',
        person.user.present? ? 'Yes' : 'No'
      ]
      values << (person.consumer_role.present? ? 'Yes' : 'No') if individual_market_is_enabled?
      values << (person.active_employee_roles.present? ? 'Yes' : 'No')
      values
    end

    def row_partial
      'exchanges/hbx_profiles/datatables/families_row'
    end

    def add_sep_link_type(allow)
      allow ? 'ajax' : 'disabled'
    end

    def cancel_enrollment_type(family, allow)
      family.all_enrollments.cancel_eligible.present? && allow ? 'ajax' : 'disabled'
    end

    def terminate_enrollment_type(family, allow)
      family.all_enrollments.can_terminate.present? && allow ? 'ajax' : 'disabled'
    end

    def update_terminated_enrollment_type(family, allow)
      return 'disabled' unless allow

      end_date_update_eligibles = family.active_household.hbx_enrollments.any?(&:is_admin_reinstate_or_end_date_update_eligible?)
      end_date_update_eligibles ? 'ajax' : 'disabled'
    end

    def reinstate_enrollment_type(family, allow)
      return 'disabled' unless allow

      reinstate_eligibles = family.active_household.hbx_enrollments.any?(&:is_admin_reinstate_or_end_date_update_eligible?)
      reinstate_eligibles ? 'ajax' : 'disabled'
    end

    def secure_message_link_type(family, current_user)
      person = family.primary_applicant.person
      (person.user.present? || person.emails.present?) && current_user.person.hbx_staff_role ? 'ajax' : 'disabled'
    end

    def aptc_csr_link_type(family, allow)
      family.active_household.latest_active_tax_household.present? && allow ? 'ajax' : 'disabled'
    end

    private

    def helpers
      ApplicationController.helpers
    end
  end
end
