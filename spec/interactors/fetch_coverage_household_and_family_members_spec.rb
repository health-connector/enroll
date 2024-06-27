# frozen_string_literal: true

require "rails_helper"

describe FetchCoverageHouseholdAndFamilyMembers, :dbclean => :after_each do
  context "when a person with family exist" do
    let(:person) {FactoryBot.create(:person, :with_family)}

    it "should fetch primary family" do
      context = described_class.call(primary_family: person.primary_family)
      expect(context.family_members.present?).to be_truthy
      expect(context.coverage_household.present?).to be_truthy
    end
  end

  context "when a family without coverage_households exist" do
    let(:person) {FactoryBot.create(:person, :with_family)}
    let(:family) {person.primary_family}
    let(:active_household) {family.active_household}

    before do
      allow(active_household).to receive(:immediate_family_coverage_household).and_return(nil)
    end

    subject do
      described_class.call(primary_family: family)
    end

    it "should not fetch family members" do
      expect(subject.family_members.present?).to be_falsey
    end

    it "should not fetch coverage_household" do
      expect(subject.coverage_household.present?).to be_falsey
    end

    it "return failure" do
      expect(subject.failure?).to be true
      expect(subject.message.to_s).to eq "no immediate_family_coverage_household for this family"
    end
  end

  context "when there is no family assigned to the context" do
    subject do
      described_class.call(primary_family: nil)
    end

    it "should not fetch family members" do
      expect(subject.family_members.present?).to be_falsey
    end

    it "should not fetch coverage_household" do
      expect(subject.coverage_household.present?).to be_falsey
    end

    it "return failure and a message" do
      expect(subject.failure?).to be true
      expect(subject.message.to_s).to eq "missing primary_family"
    end
  end
end
