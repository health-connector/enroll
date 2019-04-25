require 'rails_helper'

module BenefitSponsors
  RSpec.describe ::BenefitSponsors::SponsoredBenefits::ContributionLevel, :dbclean => :after_each do
    describe "given nothing" do
      it "requires a display name" do
        subject.valid?
        expect(subject.errors.has_key?(:display_name)).to be_truthy
      end

      it "requires a contribution unit id" do
        subject.valid?
        expect(subject.errors.has_key?(:contribution_unit_id)).to be_truthy
      end

      it "contribution_factor should be 0.0" do
        subject.valid?
        expect(subject.contribution_factor).to eq(0.0)
      end
    end
  end
end


