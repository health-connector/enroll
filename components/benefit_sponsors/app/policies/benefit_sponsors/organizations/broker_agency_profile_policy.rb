module BenefitSponsors
  module Organizations
    class BrokerAgencyProfilePolicy < ::ApplicationPolicy
      def redirect_signup?
        return false if user.blank?

        user.has_hbx_staff_role? || user.has_broker_role?
      end

      def access_to_broker_agency_profile?
        return true if shop_market_admin?
        return true if has_matching_broker_role?
        return true if has_matching_broker_agency_staff_role?

        false
      end

      def index?
        return true if shop_market_admin?

        false
      end

      # NOTE: this method is only used by the BrokerAgencyProfileStaffRolesController
      def new?
        access_to_broker_agency_profile?
      end

      def show?
        access_to_broker_agency_profile?
      end

      def staff_index?
        return true if shop_market_admin?

        false
      end

      def family_index?
        access_to_broker_agency_profile?
      end

      def family_datatable?
        access_to_broker_agency_profile?
      end

      def commission_statements?
        access_to_broker_agency_profile?
      end

      def show_commission_statement?
        access_to_broker_agency_profile?
      end

      def download_commission_statement?
        access_to_broker_agency_profile?
      end

      def general_agency_index?
        access_to_broker_agency_profile?
      end

      def messages?
        access_to_broker_agency_profile?
      end

      def inbox?
        access_to_broker_agency_profile?
      end

      protected

      def has_matching_broker_agency_staff_role?
        staff_roles = account_holder_person&.broker_agency_staff_roles || []
        staff_roles&.any? do |sr|
          sr.active? &&
            (
              sr.broker_agency_profile_id == record.id ||
                sr.benefit_sponsors_broker_agency_profile_id == record.id
            )
        end
      end

      def has_matching_broker_role?
        broker_role = account_holder_person&.broker_role
        return false unless broker_role

        broker_role&.benefit_sponsors_broker_agency_profile_id == record.id &&
          broker_role&.active?
      end
    end
  end
end
