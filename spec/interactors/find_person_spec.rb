# frozen_string_literal: true

require "rails_helper"

describe FindPerson, :dbclean => :after_each do
  let(:person) {FactoryBot.create(:person)}

  context "when a person does exist in db" do
    it "should find person" do
      context = described_class.call(params: {person_id: person.id})
      expect(context.person).to eq person
    end
  end

  context "when a person ID is invalid" do
    it "should return error" do
      context = described_class.call(params: {person_id: "1234"})

      expect(context.person).to be nil
      expect(context.failure?).to be true
      expect(context.message.to_s).to eq "invalid Person ID"
    end
  end

  context "when a person does not exist in db" do
    it "should return error" do
      context = described_class.call(params: {person_id: "6222a71ed44d05620290b472"})

      expect(context.person).to be nil
      expect(context.failure?).to be true
      expect(context.message.to_s).to eq "invalid Person ID"
    end
  end
end
