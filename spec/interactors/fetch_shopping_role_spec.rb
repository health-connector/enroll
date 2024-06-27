# frozen_string_literal: true

require "rails_helper"

describe FetchShoppingRole, :dbclean => :after_each do
  context "when a person with employee_role exist" do
    let!(:person) {FactoryBot.create(:person, :with_employee_role, :with_family)}
    let!(:employee_role) { person.employee_roles.first }

    it "should fetch employee_role" do
      allow(person).to receive(:active_employee_roles).and_return([employee_role])
      context = described_class.call(person: person)
      expect(context.employee_role.present?).to be_truthy
    end
  end

  context "when a person without employee_role exist" do
    let(:person) {FactoryBot.create(:person)}

    subject do
      described_class.call(person: person)
    end

    it "return's nil role" do
      expect(subject.role).to eq nil
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
      expect(subject.message.to_s).to eq "missing person"
    end
  end
end
