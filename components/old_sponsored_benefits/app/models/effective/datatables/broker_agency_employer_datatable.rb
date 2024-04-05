# module SponsoredBenefits
module Effective
  module Datatables
    class BrokerAgencyEmployerDatatable < ::Effective::MongoidDatatable

      datatable do
        table_column :legal_name, :label => 'Legal Name', :proc => proc { |row|
                                                                     if row.broker_relationship_inactive?
                                                                       row.legal_name
                                                                     else
                                                                       (link_to row.legal_name, main_app.employers_employer_profile_path(id: row.sponsor_profile_id, :tab => 'home'))
                                                                     end
                                                                   }, :sortable => false, :filter => false
        table_column :fein, :label => 'FEIN', :proc => proc { |row| er_fein(row) }, :sortable => false, :filter => false
        table_column :ee_count, :label => 'EE Count', :proc => proc { |row| ee_count(row) }, :sortable => false, :filter => false
        table_column :er_state, :label => 'ER State', :proc => proc { |row| er_state(row) }, :sortable => false, :filter => false
        table_column :effective_date, :label => 'Effective Date', :proc => proc { |row|

                                                                             active_plan_year_start = row.try(:employer_profile).try(:latest_plan_year).try(:start_on)
                                                                             if active_plan_year_start.nil?
                                                                               "No Active Plan"
                                                                             else
                                                                               active_plan_year_start
                                                                             end

                                                                           }, :sortable => false, :filter => false
        table_column :broker, :label => 'Broker', :proc => proc { |row| broker_name(row) }, :sortable => false, :filter => false
        table_column :actions, :width => '50px', :proc => proc { |row|
          dropdown = [
           # Link Structure: ['Link Name', link_path(:params), 'link_type'], link_type can be 'ajax', 'static', or 'disabled'
           ['View Quotes', sponsored_benefits.organizations_plan_design_organization_plan_design_proposals_path(row), 'ajax'],
           ['Create Quote', sponsored_benefits.new_organizations_plan_design_organization_plan_design_proposal_path(row), 'static'],
           ['Edit Employer Details', sponsored_benefits.edit_organizations_plan_design_organization_path(row), edit_employer_link_type(row)],
           ['Remove Employer', sponsored_benefits.organizations_plan_design_organization_path(row),
            remove_employer_link_type(row),
            "Are you sure you want to remove this employer?"]
          ]
          render partial: 'datatables/shared/dropdown', locals: {dropdowns: dropdown, row_actions_id: "employers_actions_#{row.id}"}, formats: :html
        }, :filter => false, :sortable => false
      end

      def remove_employer_link_type(employer)
        if employer.is_prospect?
          'delete with confirm'
        else
          'disabled'
        end
      end

      def edit_employer_link_type(employer)
        employer.is_prospect? ? 'ajax' : 'disabled'
      end

      def broker_name(row)
        row.broker_agency_profile.primary_broker_role.person.full_name
      end

      scopes do
        scope :legal_name, "Hello"
      end

      def ee_count(row)
        return 'N/A' if row.is_prospect? || row.broker_relationship_inactive?

        row.employer_profile.roster_size
      end

      def er_state(row)
        return 'N/A' if row.is_prospect?
        return 'Former Client' if row.broker_relationship_inactive?

        row.employer_profile.aasm_state.capitalize
      end

      def er_fein(row)
        return 'N/A' if row.is_prospect? || row.broker_relationship_inactive?

        row.fein
      end

      class << self
        attr_accessor :profile_id
      end

      def collection
        @employers = Queries::PlanDesignOrganizationQuery.new(attributes) unless (defined? @employers) && @employers.present?
        @employers
      end

      def global_search?
        true
      end

      def global_search_method
        :datatable_search
      end

      def search_column(collection, table_column, search_term, sql_column)
        if table_column[:name] == 'legal_name'
          collection.datatable_search(search_term)
        elsif table_column[:name] == 'fein'
          collection.datatable_search_fein(search_term)
        else
          super
        end
      end

      def nested_filter_definition
        {
          sponsors: [
                { scope: 'all', label: 'All'},
                { scope: 'active_sponsors', label: 'Active'},
                { scope: 'inactive_sponsors', label: 'Inactive'},
                { scope: 'prospect_sponsors', label: "Prospects" }
              ],
          top_scope: :sponsors
        }
      end

      def authorized?(current_user, _controller, _action, _resource)
        return false unless current_user
        return true if current_user.has_hbx_staff_role?
        return false unless current_user.person

        broker_agency = BenefitSponsors::Organizations::BrokerAgencyProfile.find(attributes[:profile_id])
        broker_agency_staff_roles = current_user.person.broker_agency_staff_roles.select(&:is_active?)

        allowed_as_staff = broker_agency_staff_roles.any? do |basr|
          basr.benefit_sponsors_broker_agency_profile_id == broker_agency.id
        end

        return true if allowed_as_staff

        broker_role = current_user.person.broker_role
        return false unless broker_role
        return false unless broker_role.active?

        broker_role.benefit_sponsors_broker_agency_profile_id == broker_agency.id
      end
    end
  end
end
# end
