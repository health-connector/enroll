# frozen_string_literal: true

module Effective
  module Datatables
    class GeneralAgencyDataTable < Effective::MongoidDatatable
      datatable do
        table_column :hbx_id, :label => 'HBX Acct', :proc => proc { |row|  row.employer_profile.hbx_id }, :filter => false, :sortable => false
        table_column :legal_name, :label => 'Legal Name', :proc => proc { |row|  link_to row.employer_profile.legal_name, "#{employers_employer_profile_path(row.employer_profile.id)}?tab=home" }, :filter => false, :sortable => true
        table_column :fein, :label => 'FEIN', :proc => proc { |row| number_to_obscured_fein(row.employer_profile.fein) }, :filter => false, :sortable => false
        table_column :roster_size, :label => 'EE Ct', :proc => proc { |row| row.employer_profile.roster_size  }, :filter => false, :sortable => false
        table_column :roster_size, :label => 'EE Ct', :proc => proc { |row| row.employer_profile.roster_size  }, :filter => false, :sortable => false
        table_column :aasm_state, :label => 'Enroll Status', :proc => proc { |row| row.employer_profile.aasm_state.humanize }, :filter => false, :sortable => true
        table_column :effective_date, :label => 'Effective Date', :proc => proc {  |row|
                                                                             content_tag(:span) do
                                                                               content_tag(:span, class: 'name') do
                                                                                 row.employer_profile.try(:published_plan_year).try(:effective_date).to_s
                                                                               end +
                                                                                 content_tag(:span) do
                                                                                   link_to ' (Review)', employers_premium_statement_path(row.employer_profile.id)
                                                                                 end
                                                                             end
                                                                           }, :filter => false, :sortable => true

        table_column :broker_agency_profile, :label => 'Broker Agency Name', :proc => proc { |row|
                                                                                        row.employer_profile.broker_agency_profile.organization.legal_name if row.employer_profile.broker_agency_profile.present?
                                                                                      }, :filter => false, :sortable => false
      end

      def collection
        general_agency_profile = GeneralAgencyProfile.find(attributes[:id])
        @employer_list = Organization.by_general_agency_profile(general_agency_profile.id)
      end

      def global_search?
        true
      end

      def nested_filter_definition; end

      def authorized?(current_user, _controller, _action, _resource)
        general_agency_profile = GeneralAgencyProfile.find(attributes[:id])
        AccessPolicies::GeneralAgencyProfile.new(current_user).view_families(general_agency_profile)
      end
    end
  end
end
