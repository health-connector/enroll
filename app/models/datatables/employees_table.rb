# frozen_string_literal: true

module Datatables
  # Table definition for the employer portal's Employees tab. Implements the
  # table contract documented in Datatables::FragmentRendering, except the CSV
  # methods: the tab renders no export button, and its roster CSV is the separate
  # "Download Employee Roster" link served by
  # BenefitSponsors::Profiles::Employers::EmployerProfilesController#export_census_employees.
  #
  # It lives in the main app rather than the benefit_sponsors engine because the
  # collection it wraps, Queries::EmployeeDatatableQuery, does.
  #
  # Which columns render depends on the employer's applications: a renewal
  # application adds the two renewal columns, an off-cycle application adds the
  # off-cycle ones, and a terminated current plan year drops the current-year
  # package and enrollment-status columns.
  class EmployeesTable
    include Config::AcaModelConcern

    BULK_ACTIONS = [
      { selection: 'enroll', label: 'Employee will enroll',
        confirm: 'These employees will be used to estimate your group size and participation rate' },
      { selection: 'waive', label: 'Employee will not enroll with valid waiver',
        confirm: 'Remember, your group size can affect your premium rates' },
      { selection: 'will_not_participate', label: 'Employee will not enroll with invalid waiver',
        confirm: 'Remember, your participation rate can affect your group premium rates' }
    ].freeze

    def initialize(employer_profile)
      @employer_profile = employer_profile
    end

    def param_key
      'employees'
    end

    # No column is user-sortable; employee_name is the default-ordered column
    # (index 0 of the sortable set, asc), so its header carries the sort
    # indicator and its cells the sort shading.
    def columns
      cols = [
        { name: 'bulk_actions',  label: '',              sortable: false, type: :bulk_actions_column, header: :bulk_all },
        { name: 'employee_name', label: 'Employee Name', sortable: false, type: :string, width: '50px', ordered: true },
        { name: 'dob',           label: 'DOB',           sortable: false, type: :string },
        { name: 'hired_on',      label: 'Hired On',      sortable: false, type: :string },
        { name: 'terminated_on', label: 'Terminated On', sortable: false, type: :string },
        { name: 'status',        label: 'Status',        sortable: false, type: :string }
      ]
      cols << { name: 'benefit_package', label: 'Benefit Package', sortable: false, type: :string } unless current_py_terminated?
      cols << { name: 'renewal_benefit_package', label: 'Renewal Benefit Package', sortable: false, type: :string } if renewal?
      cols << { name: 'off_cycle_benefit_package', label: 'Off-Cycle Benefit Package', sortable: false, type: :string } if off_cycle?
      cols << { name: 'enrollment_status', label: 'Enrollment Status', sortable: false, type: :string } unless current_py_terminated?
      cols << { name: 'renewal_enrollment_status', label: 'Renewal Enrollment Status', sortable: false, type: :string } if renewal?
      if off_cycle? && off_cycle_submitted?
        cols << { name: 'off_cycle_enrollment_status', label: 'Off Cycle Enrollment Status', sortable: false, type: :string }
      end
      cols << { name: 'est_participation', label: 'Est Participation', sortable: false, type: :string } if show_est_participation?
      cols << { name: 'actions', label: '', sortable: false, type: :string, width: '50px' }
      cols
    end

    def collection(attributes)
      Queries::EmployeeDatatableQuery.new(attributes.merge(id: @employer_profile.id))
    end

    def global_search?
      true
    end

    def filters
      {
        employers: [
          { scope: 'active_alone', label: 'Active only' },
          { scope: 'active', label: 'Active & COBRA' },
          { scope: 'by_cobra', label: 'COBRA only' },
          { scope: 'terminated', label: 'Terminated' },
          { scope: 'all', label: 'All' }
        ],
        top_scope: :employers
      }
    end

    def filter_scopes
      [:employers]
    end

    def date_filter
      nil
    end

    def default_order_column
      'employee_name'
    end

    def column_index_offset
      0
    end

    # Each action posts the checked census employee ids to the expected-selection
    # endpoint with its own selection value.
    def bulk_actions
      BULK_ACTIONS.map do |action|
        {
          label: action[:label],
          url: routes.change_expected_selection_employers_employer_profile_census_employees_path(
            @employer_profile, expected_selection: action[:selection]
          ),
          confirm: action[:confirm]
        }
      end
    end

    def disable_selectric?
      false
    end

    def buttons
      []
    end

    def per_page_options
      [10, 25, 50, 100]
    end

    def layout
      Datatables::Layouts::STANDARD
    end

    def row_partial
      'benefit_sponsors/profiles/employers/employer_profiles/datatables/employees_row'
    end

    # Row-action dropdown link types.
    def terminate_link_type(census_employee)
      census_employee.is_terminate_possible? ? 'ajax' : 'disabled'
    end

    def rehire_link_type(census_employee)
      census_employee.is_rehired_possible? ? 'ajax' : 'disabled'
    end

    def cobra_link_type(census_employee)
      census_employee.is_cobra_possible? ? 'ajax' : 'disabled'
    end

    # Benefit package cells show the display title only where the broker UI
    # enhancements are on.
    def benefit_package_title(package)
      return if package.blank?

      EnrollRegistry[:employer_broker_ui_enhancements].enabled? ? package.display_title.capitalize : package.title.capitalize
    end

    # Expected selection is only collected where the individual market is off.
    def show_est_participation?
      !individual_market_is_enabled?
    end

    def renewal?
      @employer_profile.renewal_benefit_application.present?
    end

    def off_cycle?
      @employer_profile.off_cycle_benefit_application.present?
    end

    def off_cycle_submitted?
      @employer_profile.off_cycle_benefit_application&.is_submitted? || false
    end

    # Only an employer that has moved to an off-cycle application can have its
    # current plan year terminated.
    def current_py_terminated?
      return false unless off_cycle?

      @employer_profile.current_benefit_application&.terminated? || false
    end

    private

    def routes
      Rails.application.routes.url_helpers
    end
  end
end
