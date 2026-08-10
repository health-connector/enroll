# frozen_string_literal: true

module SponsoredBenefits
  module Datatables
    # Table definition for the quote form's Employee Roster. Implements the table
    # contract documented in ::Datatables::FragmentRendering, except the CSV
    # methods: the roster renders no export button, and its CSV is the separate
    # "Download Employee Roster" link beside the table.
    #
    # With no filter tab picked the roster shows active and COBRA employees
    # together, which is the "Active & COBRA" tab's scope rather than the first
    # tab's — so the rows on arrival belong to a tab that is not highlighted.
    class PlanDesignEmployeesTable
      include Config::AcaModelConcern

      BULK_ACTIONS = [
        { selection: 'enroll', label: 'Employee will enroll',
          confirm: 'These employees will be used to estimate your group size and participation rate' },
        { selection: 'waive', label: 'Employee will not enroll with valid waiver',
          confirm: 'Remember, your group size can affect your premium rates' },
        { selection: 'will_not_participate', label: 'Employee will not enroll with invalid waiver',
          confirm: 'Remember, your participation rate can affect your group premium rates' }
      ].freeze

      # The roster's own grid arrangement: two button cells, no search box and no
      # processing panel, and a narrower table column than the standard one.
      LAYOUT = [
        [
          { class: 'col-sm-7 col-md-7', features: [:buttons] },
          { class: 'col-sm-5 col-md-5', features: [] }
        ],
        [
          { class: 'col-sm-12 col-md-12', features: [] }
        ],
        [
          { class: 'col-sm-11 col-md-11', features: [:table] },
          { class: 'col-sm-1 col-md-1', features: [] }
        ],
        [
          { class: 'col-sm-10 col-md-10', features: [:info] },
          { class: 'col-sm-1 col-md-1', features: [:length] }
        ],
        [
          { class: 'col-sm-12 col-md-12', features: [:pagination] }
        ]
      ].freeze

      attr_reader :plan_design_proposal

      def initialize(plan_design_proposal)
        @plan_design_proposal = plan_design_proposal
      end

      def param_key
        'plan_design_employees'
      end

      # employee_name is the default-ordered column, so its header carries the
      # sort indicator and its cells the sort shading.
      def columns
        cols = [
          { name: 'bulk_actions',  label: '',              sortable: false, type: :bulk_actions_column, header: :bulk_all },
          { name: 'employee_name', label: 'Employee Name', sortable: false, type: :string, width: '50px', ordered: true },
          { name: 'dob',           label: 'DOB',           sortable: false, type: :string },
          { name: 'hired_on',      label: 'Hired On',      sortable: false, type: :string },
          { name: 'status',        label: 'Status',        sortable: false, type: :string }
        ]
        cols << { name: 'est_participation', label: 'Est Participation', sortable: false, type: :string } if show_est_participation?
        cols << { name: 'actions', label: '', sortable: false, type: :string, width: '50px' }
        cols
      end

      def collection(attributes)
        Queries::PlanDesignEmployeeQuery.new(attributes.merge(id: benefit_sponsorship.id))
      end

      # No search box renders on this roster.
      def global_search?
        false
      end

      def filters
        {
          employees: [
            { scope: 'active_alone', label: 'Active only' },
            { scope: 'active', label: 'Active & COBRA' },
            { scope: 'by_cobra', label: 'COBRA only' },
            { scope: 'all', label: 'All' }
          ],
          top_scope: :employees
        }
      end

      def filter_scopes
        [:employees]
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
            url: routes.expected_selection_plan_design_proposal_plan_design_census_employees_path(
              @plan_design_proposal, expected_selection: action[:selection]
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
        LAYOUT
      end

      def row_partial
        'sponsored_benefits/organizations/plan_design_proposals/datatables/plan_design_employees_row'
      end

      def benefit_sponsorship
        @benefit_sponsorship ||= @plan_design_proposal.profile.benefit_sponsorships.first
      end

      # Expected selection is only collected where the individual market is off.
      def show_est_participation?
        !individual_market_is_enabled?
      end

      private

      def routes
        SponsoredBenefits::Engine.routes.url_helpers
      end
    end
  end
end
