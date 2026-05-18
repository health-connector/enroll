# frozen_string_literal: true

require 'rails_helper'
require File.join(Rails.root, "spec", "support", "acapi_vocabulary_spec_helpers")

RSpec.describe "events/residency/verification_request.xml.haml", type: :view do
  include AcapiVocabularySpecHelpers

  before(:all) do
    download_vocabularies
  end

  (1..15).each do |rnd|
    describe "given a generated individual, round #{rnd}" do
      let(:individual) { FactoryBot.build(:generative_individual) }

      before :each do
        render template: "events/residency/verification_request", locals: { individual: individual }
      end

      it "should be schema valid" do
        expect(validate_with_schema(Nokogiri::XML(rendered))).to eq []
      end
    end
  end
end
