require 'rails_helper'

module BenefitSponsors
  RSpec.describe ::BenefitSponsors::SponsoredBenefits::PricingDeterminationTier, :dbclean => :after_each do
    describe "given nothing" do
      it "price should be 0.0" do
        subject.valid?
        expect(subject.price).to eq(0.0)
      end
    end
  end
end
