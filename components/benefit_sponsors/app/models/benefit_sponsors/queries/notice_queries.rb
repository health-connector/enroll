# frozen_string_literal: true

module BenefitSponsors
  module Queries
    class NoticeQueries

      def self.initial_employers_by_effective_on_and_state(aasm_state:, start_on: TimeKeeper.date_of_record)
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where({
                                                                         :benefit_applications => {:"$elemMatch" => {
                                                                           :aasm_state => aasm_state,
                                                                           :"benefit_application_items.effective_period.min" => start_on
                                                                         }}
                                                                       })
      end

      def self.organizations_for_force_publish(new_date)
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where({
                                                                         :benefit_applications => {:"$elemMatch" => {
                                                                           :aasm_state => :draft,
                                                                           :"benefit_application_items.effective_period.min" => new_date.next_month.beginning_of_month
                                                                         }}
                                                                       })
      end

      def self.organizations_for_low_enrollment_notice(current_date)
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where({
                                                                         :benefit_applications => {:"$elemMatch" => {
                                                                           :aasm_state => :enrollment_open,
                                                                           :"open_enrollment_period.max" => current_date + 2.days
                                                                         }}
                                                                       })
      end

      def self.initial_employers_in_enrolled_state
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where({
                                                                         :benefit_applications => {:"$elemMatch" => {
                                                                           :aasm_state => :enrollment_closed
                                                                         }}
                                                                       })
      end

      def self.initial_employers_in_ineligible_state
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where({
                                                                         :benefit_applications => {:"$elemMatch" => {
                                                                           :aasm_state => :enrollment_ineligible
                                                                         }}
                                                                       })
      end
    end
  end
end