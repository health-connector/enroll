# frozen_string_literal: true

module Effective
  module Datatables
    class BenefitSponsorsEmployerDatatable < Effective::MongoidDatatable
      include Config::AcaModelConcern
      include Config::SiteHelper


      SOURCE_KINDS = ([:all] + BenefitSponsors::BenefitSponsorships::BenefitSponsorship::SOURCE_KINDS).freeze

      datatable do

        table_column :created_at, visible: false, filter: false

        bulk_actions_column(partial: 'datatables/employers/bulk_actions_column') do
          bulk_action 'Generate Invoice', generate_invoice_exchanges_hbx_profiles_path, data: { confirm: 'Generate Invoices?', no_turbolink: true }
          bulk_action 'Mark Binder Paid', binder_paid_exchanges_hbx_profiles_path, data: {  confirm: 'Mark Binder Paid?', no_turbolink: true }
        end

        table_column :legal_name, :proc => proc { |row|
                                             @employer_profile = row.organization.employer_profile
                                             (link_to row.organization.legal_name.titleize, benefit_sponsors.profiles_employers_employer_profile_path(@employer_profile.id, :tab => 'home'))

                                           }, :sortable => false, :filter => false
        table_column :fein, :label => 'FEIN', :proc => proc { |row| row.organization.fein }, :sortable => false, :filter => false
        table_column :hbx_id, :label => 'HBX ID', :proc => proc { |row| row.organization.hbx_id }, :sortable => false, :filter => false
        table_column :broker, :proc => proc { |_row|
          @employer_profile.try(:active_broker_agency_legal_name).try(:titleize) #if row.employer_profile.broker_agency_profile.present?
        }, :filter => false, sortable: false

        # TODO: Make this based on settings. MA does not use, but others might.
        # table_column :general_agency, :proc => Proc.new { |row|
        #   @employer_profile.try(:active_general_agency_legal_name).try(:titleize) #if row.employer_profile.active_general_agency_legal_name.present?
        # }, :filter => false

        # table_column :conversion, :proc => Proc.new { |row|
        #   boolean_to_glyph(row.is_conversion?)}, :filter => {include_blank: false, :as => :select, :collection => ['All','Yes', 'No'], :selected => 'All'}

        table_column :source_kind, :proc => proc { |row|
                                              row.source_kind.to_s.humanize
                                            },
                                   :filter => {include_blank: false, :as => :select, :collection => SOURCE_KINDS, :selected => "all"}

        table_column :plan_year_state, :proc => proc { |row|
                                                  benefit_application_summarized_state(row.latest_application) if row.latest_application.present?
                                                }, :filter => false
        table_column :effective_date, :proc => proc { |row|
                                                 row.latest_application.effective_period.min.strftime("%m/%d/%Y") if row.latest_application.present?
                                               }, :filter => false, :sortable => true

        table_column :invoiced?, :proc => proc { |_row|
                                            boolean_to_glyph(@employer_profile.current_month_invoice.present?)
                                          }, :filter => false

        # table_column :xml_submitted, :label => 'XML Submitted', :proc => Proc.new {|row| format_time_display(@employer_profile.xml_transmitted_timestamp)}, :filter => false, :sortable => false

        if employer_attestation_is_enabled?
          table_column :attestation_status, :label => 'Attestation Status', :proc => proc {|row|
            #TODO: fix this after employer attestation is fixed, this is only temporary fix
            #used below condition, as employer_attestation is embedded from both employer profile and benefit sponsorship
            if row.employer_attestation.present?
              row.employer_attestation.aasm_state.titleize
            elsif @employer_profile.employer_attestation.present?
              @employer_profile.employer_attestation.aasm_state.titleize
            end
          }, :filter => false, :sortable => false
        end

        table_column :actions, :width => '50px', :proc => proc { |row|
          dropdown = [
           # Link Structure: ['Link Name', link_path(:params), 'link_type'], link_type can be 'ajax', 'static', or 'disabled'
           ['Transmit XML', "#", "disabled"],
           ['Generate Invoice', generate_invoice_exchanges_hbx_profiles_path(ids: [row.id]), generate_invoice_link_type(@employer_profile)],
           ['Create Plan Year', main_app.new_benefit_application_exchanges_hbx_profiles_path(benefit_sponsorship_id: row.id, employer_actions_id: "employer_actions_#{@employer_profile.id}"), pundit_allow(HbxProfile, :can_create_benefit_application?) ? 'ajax' : 'hide'],
           ['Change FEIN', edit_fein_exchanges_hbx_profiles_path(id: row.id, employer_actions_id: "employer_actions_#{@employer_profile.id}"), pundit_allow(HbxProfile, :can_change_fein?) ? "ajax" : "hide"],
           ['Force Publish', edit_force_publish_exchanges_hbx_profiles_path(id: @employer_profile.latest_benefit_sponsorship.id, employer_actions_id: "employer_actions_#{@employer_profile.id}"), force_publish_link_type(row, pundit_allow(HbxProfile, :can_force_publish?))]
          ]

          dropdown.insert(2,['Plan Years', exchanges_employer_applications_path(employer_id: row, employers_action_id: "employer_actions_#{@employer_profile.id}"), 'ajax']) if pundit_allow(HbxProfile, :can_modify_plan_year?)

          if individual_market_is_enabled?
            people_id = Person.where({"employer_staff_roles.employer_profile_id" => @employer_profile._id}).map(&:id)
            dropdown.insert(2,['View Username and Email', main_app.get_user_info_exchanges_hbx_profiles_path(
              people_id: people_id,
              employers_action_id: "employer_actions_#{@employer_profile.id}"
            ), !people_id.empty? && pundit_allow(Family, :can_view_username_and_email?) ? 'ajax' : 'disabled'])
          end

          dropdown.insert(2,['Attestation', main_app.edit_employers_employer_attestation_path(id: @employer_profile.id, employer_actions_id: "employer_actions_#{@employer_profile.id}"), 'ajax']) if employer_attestation_is_enabled?
          if row.oe_extendable_benefit_applications.present? && pundit_allow(HbxProfile, :can_extend_open_enrollment?)
            dropdown.insert(3,['Extend Open Enrollment', main_app.oe_extendable_applications_exchanges_hbx_profiles_path(id: @employer_profile.latest_benefit_sponsorship.id, employer_actions_id: "employer_actions_#{@employer_profile.id}"), 'ajax'])
          end

          if row.oe_extended_applications.present? && pundit_allow(HbxProfile, :can_extend_open_enrollment?)
            dropdown.insert(4, ['Close Open Enrollment', main_app.oe_extended_applications_exchanges_hbx_profiles_path(
              id: @employer_profile.latest_benefit_sponsorship.id,
              employer_actions_id: "employer_actions_#{@employer_profile.id}"
            ), 'ajax'])
          end

          render partial: 'datatables/shared/dropdown', locals: {dropdowns: dropdown, row_actions_id: "employer_actions_#{@employer_profile.id}"}, formats: :html
        }, :filter => false, :sortable => false

      end

      def generate_invoice_link_type(row)
        row.current_month_invoice.present? ? 'disabled' : 'post_ajax'
      end

      def get_latest_draft_benefit_application(benefit_sponsorship)
        draft_apps = benefit_sponsorship.benefit_applications.draft_state
        draft_apps.present? ? draft_apps.last : ""
      end

      def business_policy_accepted?(draft_application)
        TimeKeeper.date_of_record > draft_application.last_day_to_publish && TimeKeeper.date_of_record < draft_application.start_on
      end

      def force_publish_link_type(benefit_sponsorship, allow)
        draft_application = get_latest_draft_benefit_application(benefit_sponsorship)
        policy_accepted_and_allow = draft_application.present? && business_policy_accepted?(draft_application) && allow
        policy_accepted_and_allow ? 'ajax' : 'hide'
      end

      def eligible_for_publish?(benefit_application)
        (1..fte_max_count).cover?(benefit_application.fte_count) && benefit_application.sponsor_profile.is_primary_office_local?
      end

      def collection
        return @employer_collection if defined? @employer_collection

        table_query = {"$group" => {"_id" => "$_id"}}
        # States
        enrolling_states = [:draft, :enrollment_open, :enrollment_extended, :enrollment_closed, :enrollment_eligible, :binder_paid]
        # Queries
        enrolling_query = {
          "$match" => {
            :"benefit_applications.aasm_state".in => enrolling_states,
            :"benefit_applications.predecessor_id" => {:$exists => false}
          }
        }
        enrolling_renewing_query = {
          "$match" => {
            :"benefit_applications.aasm_state".in => [:draft, :enrollment_open, :enrollment_extended, :enrollment_closed, :enrollment_eligible],
            :"benefit_applications.predecessor_id" => {:$exists => true}
          }
        }
        employers_query = {"$match" => {:"benefit_applications.aasm_state".in => [:enrollment_closed, :enrollment_eligible, :active]}}
        enrolled_query = {"$match" => {:"benefit_applications.aasm_state".in => [:enrollment_closed, :enrollment_eligible, :active]}}
        employer_attestation_orgs = BenefitSponsors::Organizations::Organization.employer_profiles.where(
          :"profiles.employer_attestation.aasm_state".in => employer_attestation_kinds
        )
        employer_attestations_query = {
          "$match" => {:organization.in => employer_attestation_orgs.collect{|org| org.id.to_s}}
        }
        if attributes[:employers].present? && !['all'].include?(attributes[:employers])
          table_query.merge!(employers_query) if employer_kinds.include?(attributes[:employers])
          if attributes[:enrolling].present?
            if attributes[:enrolling_initial].present? || attributes[:enrolling_renewing].present?
              table_query.merge!(enrolling_query) if attributes[:enrolling_initial].present? && attributes[:enrolling_initial] != 'all'
              table_query.merge!(enrolling_renewing_query) if attributes[:enrolling_renewing].present? && attributes[:enrolling_renewing] != 'all'
              table_query.merge!(enrolling_query) if attributes[:enrolling_initial].present? && attributes[:enrolling_initial] == 'all' || attributes[:enrolling_renewing].present? && attributes[:enrolling_renewing] == 'all'
            else
              table_query.merge!(enrolling_query)
            end
          end

          table_query.merge!(enrolled_query) if attributes[:enrolled].present?
          table_query.merge!(employer_attestations_query) if attributes[:employer_attestations].present?

          if attributes[:upcoming_dates].present?
            if date = Date.strptime(attributes[:upcoming_dates], "%m/%d/%Y")
              upcoming_dates_query = {
                "$match" => {:"benefit_applications.effective_period.min" => date}
              }
              table_query.merge!(upcoming_dates_query)
            end
          end

          if attributes[:attestations].present? && attributes[:attestations] != "employer_attestations"
            attestations_by_kinds_orgs = BenefitSponsors::Organizations::Organization.employer_profiles.where(:"profiles.employer_attestation.aasm_state" => attestation_kind)
            # self.where(:"organization".in => orgs.collect{|org| org.id})}
            employer_attestation_by_kind_query = {
              "$match" => {:organization.in => attestations_by_kinds_orgs.collect{|org| org.id.to_s}}
            }
            table_query.merge!(employer_attestation_by_kind_query)
          end
        end
        benefit_sponsorships ||= BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.aggregate([table_query])
        sponsorship_ids = benefit_sponsorships.map { |id| id["_id"] }
        @employer_collection = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:_id.in => sponsorship_ids)
      end

      def global_search?
        true
      end

      def global_search_method
        :datatable_search
      end

      def employer_kinds
        ['benefit_sponsorship_applicant','benefit_application_enrolling','benefit_application_enrolled', 'employer_attestations']
      end

      def employer_attestation_kinds
        kinds ||= EmployerAttestation::ATTESTATION_KINDS
      end

      def enrolling_kinds
        []
      end

      def enrolled_kinds
        []
      end

      def search_column(collection, table_column, search_term, sql_column)
        if table_column[:name] == 'source_kind' || table_column[:name] == 'mid_plan_year_conversion'
          if search_term != "all"
            collection.datatable_search_for_source_kind(search_term.to_sym)
          else
            super
          end
        else
          super
        end
      end

      def nested_filter_definition
        @next_30_day = TimeKeeper.date_of_record.next_month.beginning_of_month
        @next_60_day = @next_30_day.next_month
        @next_90_day = @next_60_day.next_month

        filters = {
          enrolling_renewing:
            [
              {scope: 'all', label: 'All'},
              {scope: 'benefit_application_renewal_pending', label: 'Application Pending'},
              {scope: 'benefit_application_enrolling_renewing_oe', label: 'Open Enrollment'}
            ],
          enrolling_initial:
          [
            {scope: 'all', label: 'All'},
            {scope: 'benefit_application_pending', label: 'Application Pending'},
            {scope: 'benefit_application_enrolling_initial_oe', label: 'Open Enrollment'},
            {scope: 'benefit_application_initial_binder_paid', label: 'Binder Paid'},
            {scope: 'benefit_application_initial_binder_pending', label: 'Binder Pending'}
          ],
          enrolled:
          [
            {scope: 'benefit_application_enrolled', label: 'All' },
            {scope: 'benefit_application_suspended', label: 'Suspended' }
          ],
          upcoming_dates:
          [
            {scope: @next_30_day, label: @next_30_day },
            {scope: @next_60_day, label: @next_60_day }
          ],
          enrolling:
          [
            {scope: 'benefit_application_enrolling', label: 'All'},
            {scope: 'benefit_application_enrolling_initial', label: 'Initial', subfilter: :enrolling_initial},
            {scope: 'benefit_application_enrolling_renewing', label: 'Renewing / Converting', subfilter: :enrolling_renewing},
            {scope: 'benefit_application_enrolling', label: 'Upcoming Dates', subfilter: :upcoming_dates}
          ],
          attestations:
          [
            {scope: 'employer_attestations', label: 'All'},
            {scope: 'submitted', label: 'Submitted'},
            {scope: 'pending', label: 'Pending'},
            {scope: 'approved', label: 'Approved'},
            {scope: 'denied', label: 'Denied'}
          ],
          employers:
         [
           {scope: 'all', label: 'All'},
           {scope: 'benefit_sponsorship_applicant', label: 'Applicants'},
           {scope: 'benefit_application_enrolling', label: 'Enrolling', subfilter: :enrolling},
           {scope: 'benefit_application_enrolled', label: 'Enrolled', subfilter: :enrolled}
         ],
          top_scope: :employers
        }
        filters[:employers] << {scope: 'employer_attestations', label: 'Employer Attestations', subfilter: :attestations} if employer_attestation_is_enabled?
        filters
      end
    end
  end
end
