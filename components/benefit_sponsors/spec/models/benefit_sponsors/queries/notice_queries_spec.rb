# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BenefitSponsors::Queries::NoticeQueries', :dbclean => :after_each do
  let!(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let!(:organization)     { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let!(:employer_profile)    { organization.employer_profile }
  let(:benefit_sponsorship) do
    sponsorship = employer_profile.add_benefit_sponsorship
    sponsorship.save
    sponsorship
  end
  let!(:benefit_application) do
    FactoryBot.create(:benefit_sponsors_benefit_application,
                      :with_benefit_package,
                      :benefit_sponsorship => benefit_sponsorship,
                      :aasm_state => aasm_state,
                      :default_effective_period => start_on..(start_on + 1.year) - 1.day,
                      :open_enrollment_period => open_enrollment_period)
  end

  let(:start_on) { TimeKeeper.date_of_record.beginning_of_month}
  let(:open_enrollment_period) {TimeKeeper.date_of_record.beginning_of_month }

  describe "#initial_employers_by_effective_on_and_state" do
    let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
    let(:open_enrollment_period) { TimeKeeper.date_of_record.beginning_of_month..(TimeKeeper.date_of_record.beginning_of_month + 13.days) }
    let(:aasm_state) { :enrollment_open }

    it "returns the employers with benefit applications with given state and start date" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.initial_employers_by_effective_on_and_state(start_on: start_on, aasm_state: aasm_state)

      expect(sponsorships.count).to eq 1
    end

    it "returns 0 if no employers match the criteria" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.initial_employers_by_effective_on_and_state(start_on: TimeKeeper.date_of_record, aasm_state: aasm_state)

      expect(sponsorships.count).to eq 0
    end
  end

  describe "#organizations_for_force_publish" do
    let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
    let(:open_enrollment_period) { TimeKeeper.date_of_record.beginning_of_month..(TimeKeeper.date_of_record.beginning_of_month + 13.days) }
    let(:aasm_state) { :draft }

    it "returns the employers with benefit applications eligible for force publish" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.organizations_for_force_publish(TimeKeeper.date_of_record)

      expect(sponsorships.count).to eq 1
    end

    it "returns 0 if no employers match the criteria" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.organizations_for_force_publish(start_on)

      expect(sponsorships.count).to eq 0
    end
  end

  describe "#organizations_for_low_enrollment_notice" do
    let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
    let(:open_enrollment_period) { TimeKeeper.date_of_record.beginning_of_month..(TimeKeeper.date_of_record + 2.days) }
    let(:aasm_state) { :enrollment_open }

    it "returns the employers with benefit applications oe ends in 2 days" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.organizations_for_low_enrollment_notice(TimeKeeper.date_of_record)

      expect(sponsorships.count).to eq 1
    end

    it "returns 0 if no employers match the criteria" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.organizations_for_low_enrollment_notice(start_on)

      expect(sponsorships.count).to eq 0
    end
  end

  describe "#initial_employers_in_enrolled_state" do
    let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
    let(:open_enrollment_period) { TimeKeeper.date_of_record.beginning_of_month..(TimeKeeper.date_of_record + 2.days) }
    let(:aasm_state) { :enrollment_closed }

    it "returns the employers with benefit applications oe ends in 2 days" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.initial_employers_in_enrolled_state

      expect(sponsorships.count).to eq 1
    end
  end

  describe "#initial_employers_in_ineligible_state" do
    let(:start_on) { TimeKeeper.date_of_record.next_month.beginning_of_month}
    let(:open_enrollment_period) { TimeKeeper.date_of_record.beginning_of_month..(TimeKeeper.date_of_record + 2.days) }
    let(:aasm_state) { :enrollment_ineligible }

    it "returns the employers with benefit applications oe ends in 2 days" do
      sponsorships = BenefitSponsors::Queries::NoticeQueries.initial_employers_in_ineligible_state

      expect(sponsorships.count).to eq 1
    end
  end
end