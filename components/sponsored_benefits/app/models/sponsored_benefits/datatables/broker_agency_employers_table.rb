# frozen_string_literal: true

module SponsoredBenefits
  module Datatables
    # Table definition for the broker portal's Employers page, listing the plan
    # design organizations a broker agency owns. Implements the table contract
    # documented in ::Datatables::FragmentRendering.
    #
    # The checkbox column renders only where the individual market is enabled,
    # and the dropdown it would feed is empty even there, so no bulk action is
    # ever offered.
    class BrokerAgencyEmployersTable
      include Config::AcaModelConcern

      # Benefit application states as the ER State column names them.
      APPLICATION_STATE_LABELS = {
        draft: :draft,
        enrollment_open: :enrolling,
        enrollment_eligible: :enrolled,
        binder_paid: :enrolled,
        approved: :published,
        pending: :publish_pending
      }.freeze

      RENEWING_EXCLUDED_STATES = [:active, :terminated, :termination_pending].freeze

      def initialize(broker_agency_profile)
        @broker_agency_profile = broker_agency_profile
      end

      def param_key
        'broker_agency_employers'
      end

      # No column is user-sortable; legal_name is the default-ordered column, so
      # its header carries the sort indicator and its cells the sort shading.
      def columns
        cols = []
        cols << { name: 'bulk_actions', label: '', sortable: false, type: :bulk_actions_column, header: :bulk_all } if show_bulk_actions_column?
        cols + [
          { name: 'legal_name',     label: 'Legal Name',     sortable: false, type: :string, ordered: true },
          { name: 'fein',           label: 'FEIN',           sortable: false, type: :string },
          { name: 'ee_count',       label: 'EE Count',       sortable: false, type: :string },
          { name: 'er_state',       label: 'ER State',       sortable: false, type: :string },
          { name: 'effective_date', label: 'Effective Date', sortable: false, type: :string },
          { name: 'broker',         label: 'Broker',         sortable: false, type: :string },
          { name: 'actions',        label: 'Actions',        sortable: false, type: :string, width: '50px' }
        ]
      end

      def collection(attributes)
        Queries::PlanDesignOrganizationQuery.new(attributes.merge(profile_id: @broker_agency_profile.id))
      end

      def global_search?
        true
      end

      def filters
        {
          sponsors: [
            { scope: 'all', label: 'All' },
            { scope: 'active_sponsors', label: 'Active' },
            { scope: 'inactive_sponsors', label: 'Inactive' },
            { scope: 'prospect_sponsors', label: 'Prospects' }
          ],
          top_scope: :sponsors
        }
      end

      def filter_scopes
        [:sponsors]
      end

      def date_filter
        nil
      end

      def default_order_column
        'legal_name'
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

      def layout
        ::Datatables::Layouts::STANDARD
      end

      # The actions column and the checkbox column carry no exportable text.
      def csv_headers
        export_columns.map { |col| col[:label] }
      end

      def csv_row(row)
        [row.legal_name, fein(row), employee_count(row), employer_state(row), effective_date(row), broker_name(row)]
      end

      def row_partial
        'sponsored_benefits/organizations/broker_agency_profiles/datatables/broker_agency_employers_row'
      end

      # Cell values. A prospect has no employer behind it yet, and a former
      # client's employer data is no longer the broker's to see.
      def fein(plan_design_organization)
        return 'N/A' if plan_design_organization.is_prospect? || plan_design_organization.broker_relationship_inactive?

        plan_design_organization.fein
      end

      def employee_count(plan_design_organization)
        return 'N/A' if plan_design_organization.is_prospect? || plan_design_organization.broker_relationship_inactive?

        plan_design_organization.employer_profile.roster_size
      end

      def employer_state(plan_design_organization)
        return 'N/A' if plan_design_organization.is_prospect?
        return 'Former Client' if plan_design_organization.broker_relationship_inactive?

        sponsorship = plan_design_organization.employer_profile.organization.active_benefit_sponsorship
        application_state_label(sponsorship.dt_display_benefit_application) if sponsorship.dt_display_benefit_application.present?
      end

      def effective_date(plan_design_organization)
        start_on = plan_design_organization.try(:employer_profile).try(:latest_plan_year).try(:start_on)
        return 'No Active Plan' if start_on.nil?

        start_on.strftime('%m/%d/%Y')
      end

      # The checkbox column appears only where the individual market is enabled.
      def show_bulk_actions_column?
        individual_market_is_enabled?
      end

      def broker_name(plan_design_organization)
        plan_design_organization.broker_agency_profile.primary_broker_role.person.full_name
      end

      # A benefit application succeeding another is labelled as renewing unless it
      # has already started or ended.
      def application_state_label(benefit_application)
        return if benefit_application.nil?

        renewing = benefit_application.predecessor_id.present? && RENEWING_EXCLUDED_STATES.exclude?(benefit_application.aasm_state) ? 'Renewing' : ''
        state = APPLICATION_STATE_LABELS[benefit_application.aasm_state] || benefit_application.aasm_state
        "#{renewing} #{state.to_s.humanize.titleize}".strip
      end

      # Only a prospect employer's own record may be edited or removed here.
      def edit_employer_link_type(plan_design_organization)
        plan_design_organization.is_prospect? ? 'ajax' : 'disabled'
      end

      def remove_employer_link_type(plan_design_organization)
        plan_design_organization.is_prospect? ? 'delete with confirm' : 'disabled'
      end

      private

      def export_columns
        columns.reject { |col| col[:name] == 'actions' || col[:type] == :bulk_actions_column }
      end
    end
  end
end
