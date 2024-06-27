# frozen_string_literal: true

require "rails_helper"

describe FindPrimaryFamily, :dbclean => :after_each do
  context "when a person with family exist" do
    let(:person) {FactoryBot.create(:person, :with_family)}

    it "should fetch primary family" do
      context = described_class.call(person: person)
      expect(context.primary_family.present?).to be_truthy
    end
  end

  context "when a person without family exist" do
    let(:person) {FactoryBot.create(:person)}

    it "should not fetch primary family" do
      context = described_class.call(person: person)
      expect(context.primary_family.present?).to be_falsey
      expect(context.failure?).to be true
      expect(context.message.to_s).to eq "no primary family found"
    end
  end

  context "when there is no person assigned to the context" do
    it "should not fetch primary family" do
      context = described_class.call(person: nil)
      expect(context.primary_family.present?).to be_falsey
      expect(context.failure?).to be true
      expect(context.message.to_s).to eq "missing person"
    end
  end
end
