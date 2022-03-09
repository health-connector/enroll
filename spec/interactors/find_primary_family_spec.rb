# frozen_string_literal: true

require "rails_helper"

describe FindPrimaryFamily, :dbclean => :after_each do
  let(:person) {FactoryGirl.create(:person, :with_family)}

  context "when a person does exist in db" do
    it "should find person" do
      context = described_class.call(person: person})
      expect(context.person).to eq person
    end
  end
end
