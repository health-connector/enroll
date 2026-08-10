# frozen_string_literal: true

module SponsoredBenefits
  module Datatables
    # Table definition for the broker portal's Manage Quotes page, listing a plan
    # design organization's quotes. Implements the table contract documented in
    # ::Datatables::FragmentRendering.
    #
    # effective_date is the only clickable header. The order it produces reaches
    # Queries::PlanDesignProposalsQuery#order_by, which stores the criteria and
    # never applies it, so the header toggles its direction without reordering
    # any rows.
    class PlanDesignProposalsTable
      def initialize(plan_design_organization)
        @plan_design_organization = plan_design_organization
      end

      def param_key
        'plan_design_proposals'
      end

      # title is the default-ordered column, so its header carries the sort
      # indicator until effective_date is clicked.
      def columns
        [
          { name: 'title',            label: 'Quote Name',     sortable: false, type: :string, ordered: true },
          { name: 'effective_date',   label: 'Effective Date', sortable: true,  type: :string },
          { name: 'claim_code',       label: 'Claim Code',     sortable: false, type: :string },
          { name: 'employees',        label: 'Employees',      sortable: false, type: :string },
          { name: 'families',         label: 'Families',       sortable: false, type: :string },
          { name: 'plan_option_kind', label: 'Plan Type',      sortable: false, type: :string },
          { name: 'reference_plan',   label: 'Reference Plan', sortable: false, type: :string },
          { name: 'state',            label: 'State',          sortable: false, type: :string },
          { name: 'actions',          label: 'Actions',        sortable: false, type: :string, width: '50px' }
        ]
      end

      def collection(attributes)
        Queries::PlanDesignProposalsQuery.new(attributes.merge(organization_id: @plan_design_organization.id))
      end

      def global_search?
        true
      end

      def filters
        {
          quotes: [
            { scope: 'all', label: 'All' },
            { scope: 'initial', label: 'Initial' },
            { scope: 'draft', label: 'Draft' },
            { scope: 'published', label: 'Published' },
            { scope: 'expired', label: 'Expired' }
          ],
          top_scope: :quotes
        }
      end

      def filter_scopes
        [:quotes]
      end

      def date_filter
        nil
      end

      def default_order_column
        'title'
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

      # The actions column carries no exportable text.
      def csv_headers
        columns[0..-2].map { |col| col[:label] }
      end

      def csv_row(row)
        [
          row.title,
          effective_date(row),
          claim_code(row),
          employee_count(row),
          family_count(row),
          plan_option_kind(row),
          reference_plan_name(row),
          state(row)
        ]
      end

      def row_partial
        'sponsored_benefits/organizations/plan_design_proposals/datatables/plan_design_proposals_row'
      end

      # Cell values.
      def proposal_sponsorship(proposal)
        proposal.profile.benefit_sponsorships.first
      end

      def effective_date(proposal)
        proposal_sponsorship(proposal).initial_enrollment_period.begin.strftime('%Y - %m - %d')
      end

      def claim_code(proposal)
        proposal.claim_code || 'Not Published'
      end

      def employee_count(proposal)
        proposal_sponsorship(proposal).census_employees.count
      end

      def family_count(proposal)
        proposal_sponsorship(proposal).census_employees.where({ 'census_dependents.0' => { '$exists' => true } }).count
      end

      def plan_option_kind(proposal)
        benefit_group = assigned_benefit_group(proposal)
        return 'Unassigned' if benefit_group.blank?

        benefit_group.plan_option_kind.humanize
      end

      def reference_plan_name(proposal)
        benefit_group = assigned_benefit_group(proposal)
        return 'Unassigned' if benefit_group.blank?

        benefit_group.reference_plan.name
      end

      def state(proposal)
        proposal.aasm_state.capitalize
      end

      def assigned_benefit_group(proposal)
        application = proposal_sponsorship(proposal).benefit_applications.first
        return if application.blank?

        application.benefit_groups.first
      end

      # Row-action link types. A quote leaves draft for good once published,
      # expired or claimed, after which it is view-only.
      def edit_quote_link_type(proposal)
        proposal.published? || proposal.expired? || proposal.claimed? ? 'disabled' : 'static'
      end

      # The view entry names the state the quote reached, and is disabled while
      # the quote is still a draft with nothing to view.
      def view_quote_link(proposal, show_link)
        return ['View Published Quote', show_link, 'static'] if proposal.published?
        return ['View Expired Quote', show_link, 'static'] if proposal.expired?
        return ['View Claimed Quote', show_link, 'static'] if proposal.claimed?

        ['View Published Quote', show_link, 'disabled']
      end
    end
  end
end
