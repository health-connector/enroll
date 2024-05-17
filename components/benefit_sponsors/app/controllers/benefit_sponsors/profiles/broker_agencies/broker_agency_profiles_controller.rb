# frozen_string_literal: true

require_dependency "benefit_sponsors/application_controller"

module BenefitSponsors
  module Profiles
    module BrokerAgencies
      class BrokerAgencyProfilesController < ::BenefitSponsors::ApplicationController
        # include Acapi::Notifiers
        include DataTablesAdapter
        include BenefitSponsors::Concerns::ProfileRegistration

        rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

        before_action :set_current_person, only: [:staff_index]
        before_action :load_broker_agency_profile,
                      only: %i[
                        show
                        family_index
                        family_datatable
                        show_commission_statement
                        download_commission_statement
                        messages
                      ]
        before_action :load_commission_statement,
                      only: %i[
                        show_commission_statement
                        download_commission_statement
                      ]

        layout "single_column"

        EMPLOYER_DT_COLUMN_TO_FIELD_MAP = {
          "2" => "legal_name",
          "4" => "employer_profile.aasm_state",
          "5" => "employer_profile.plan_years.start_on"
        }.freeze

        def index
          authorize BenefitSponsors::Organizations::BrokerAgencyProfile
          @broker_agency_profiles =
            BenefitSponsors::Organizations::Organization.broker_agency_profiles.map(
              &:broker_agency_profile
            )
        end

        def show
          authorize @broker_agency_profile, :redirect_signup?
          authorize @broker_agency_profile
          set_flash_by_announcement
          @provider = current_user.person
        end

        def staff_index
          authorize BenefitSponsors::Organizations::BrokerAgencyProfile
          @q = params.permit(:q)[:q]
          @staff = eligible_brokers
          @page_alphabets = page_alphabets(@staff, "last_name")
          page_no = cur_page_no(@page_alphabets.first)
          @staff = if @q.nil?
                     @staff.where(last_name: /^#{page_no}/i)
                   else
                     @staff.where(last_name: /^#{Regexp.escape(@q)}/i)
                   end
        end

        # TODO: need to refactor for cases around SHOP broker agencies
        def family_datatable
          authorize @broker_agency_profile
          dt_query = extract_datatable_parameters

          query =
            BenefitSponsors::Queries::BrokerFamiliesQuery.new(
              dt_query.search_string,
              @broker_agency_profile.id,
              @broker_agency_profile.market_kind
            )
          @total_records = query.total_count
          @records_filtered = query.filtered_count
          @families =
            query.filtered_scope.skip(dt_query.skip).limit(dt_query.take).to_a
          primary_member_ids =
            @families.map { |fam| fam.primary_family_member.person_id }
          @primary_member_cache = {}
          Person
            .where(_id: { "$in" => primary_member_ids })
            .each { |pers| @primary_member_cache[pers.id] = pers }

          @draw = dt_query.draw
        end

        def family_index
          authorize @broker_agency_profile
          @q = params.permit(:q)[:q]

          respond_to { |format| format.js {} }
        end

        def commission_statements
          profile_id = params.permit(:id)[:id]
          profile_id ||= current_user.person.broker_role.benefit_sponsors_broker_agency_profile_id if current_user&.has_broker_role?
          load_broker_agency_profile(profile_id)
          authorize @broker_agency_profile, :redirect_signup?
          authorize @broker_agency_profile
          documents = @broker_agency_profile.documents
          @statements = get_commission_statements(documents) if documents
          collect_and_sort_commission_statements
          respond_to { |format| format.js }
        end

        def show_commission_statement
          authorize @broker_agency_profile, :redirect_signup?
          authorize @broker_agency_profile

          options = {}
          options[:filename] = @commission_statement.title
          options[:type] = "application/pdf"
          options[:disposition] = "inline"
          send_data Aws::S3Storage.find(@commission_statement.identifier),
                    options
        end

        def download_commission_statement
          authorize @broker_agency_profile, :redirect_signup?
          authorize @broker_agency_profile

          options = {}
          options[:content_type] = @commission_statement.type
          options[:filename] = @commission_statement.title
          send_data Aws::S3Storage.find(@commission_statement.identifier),
                    options
        end

        def messages
          @sent_box = true
          # don't use current_user
          # messages are different for current_user is admin and broker account login
          authorize @broker_agency_profile
          @broker_provider = @broker_agency_profile.primary_broker_role.person

          respond_to { |format| format.js {} }
        end

        def inbox
          @sent_box = true

          if params["id"].present?
            provider_id = params["id"]
            @provider = Person.find(provider_id)
            @broker_agency_profile = @provider.broker_role.broker_agency_profile
          elsif params["profile_id"].present?
            provider_id = params["profile_id"]
            load_broker_agency_profile(provider_id)
          end

          authorize @broker_agency_profile

          @folder = (params[:folder] || "Inbox").capitalize
          @provider = @broker_agency_profile unless current_user.person.id.to_s == provider_id.to_s
        end

        private

        def load_broker_agency_profile(profile_id = nil)
          profile_id ||= params.permit(:id)[:id]
          @broker_agency_profile =
            ::BenefitSponsors::Organizations::BrokerAgencyProfile.find(
              profile_id
            )
        end

        def load_commission_statement
          @commission_statement =
            @broker_agency_profile.documents.find(params[:statement_id])
        end

        def user_not_authorized(exception)
          if exception.query == :redirect_signup?
            redirect_to main_app.new_user_registration_path
          elsif current_user.has_broker_agency_staff_role?
            staff_role = current_user.person.broker_agency_staff_roles.first
            redirect_to profiles_broker_agencies_broker_agency_profile_path(
              id: staff_role.benefit_sponsors_broker_agency_profile_id
            )
          else
            redirect_to benefit_sponsors.new_profiles_registration_path(
              profile_type: :broker_agency
            )
          end
        end

        def eligible_brokers
          Person
            .where("broker_role.broker_agency_profile_id": { :$exists => true })
            .where("broker_role.aasm_state": "active")
            .any_in("broker_role.market_kind": [person_market_kind, "both"])
        end

        def person_market_kind
          if @person.has_active_consumer_role?
            "individual"
          elsif @person.has_active_employee_role?
            "shop"
          end
        end

        def get_commission_statements(documents)
          commission_statements = []
          documents.each do |document|
            # grab only documents that are commission statements by checking the bucket in which they are placed
            commission_statements << document if document.identifier.include?("commission-statements")
          end
          commission_statements
        end

        def collect_and_sort_commission_statements(_sort_order = "ASC")
          @statement_years =
            (
              Settings
                .aca
                .shop_market
                .broker_agency_profile
                .minimum_commission_statement_year..TimeKeeper.date_of_record.year
            ).to_a.reverse
          @statements.sort_by!(&:date).reverse!
        end
      end
    end
  end
end
