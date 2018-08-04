require "rails_helper"

RSpec.describe Effective::Datatables::BenefitSponsorsEmployerDatatable do
  let!(:hbx_profile) { FactoryGirl.create(:hbx_profile) }
  let!(:hbx_profile2) { FactoryGirl.create(:hbx_profile) }
  let!(:benefit_sponsorship) { FactoryGirl.create(:benefit_sponsorship, hbx_profile: hbx_profile) }
  let!(:benefit_sponsorship2) { FactoryGirl.create(:benefit_sponsorship, hbx_profile: hbx_profile2) }
  describe "#collection" do
    before do
      #remove_instance_variable(:@employer_collection) if defined? @employer_collection
      #subject.attributes = {:employers => "all"}
    end
    it "returns all BenefitSponsorship without filter option" do
      expect(subject.collection.count).to eq 2
    end

    # it "returns all BenefitSponsorship " do
    #   subject.attributes = {:employers => "all"}
    #   expect(subject.collection).to eq(BenefitSponsors::BenefitSponsorships::BenefitSponsorship.all)
    # end
  end
end