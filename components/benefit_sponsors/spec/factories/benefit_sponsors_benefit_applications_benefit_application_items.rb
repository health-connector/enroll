# frozen_string_literal: true

FactoryBot.define do

  factory :benefit_sponsors_benefit_application_item, class: 'BenefitSponsors::BenefitApplications::BenefitApplicationItem' do
    effective_period do
      if default_effective_period.present?
        default_effective_period
      else
        start_on  = TimeKeeper.date_of_record.beginning_of_month
        end_on    = start_on + 1.year - 1.day
        start_on..end_on
      end
    end

    transient do
      default_effective_period nil
    end

    state :draft
    sequence_id 0
  end
end
