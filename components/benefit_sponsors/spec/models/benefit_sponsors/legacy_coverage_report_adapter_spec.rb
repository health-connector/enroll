# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::LegacyCoverageReportAdapter, dbclean: :after_each do
  describe '#search_collection' do
    let(:benefit_sponsorship) { double(profile_id: BSON::ObjectId.new) }
    let(:sponsored_benefit) { double(benefit_sponsorship: benefit_sponsorship) }

    subject do
      described_class.new([]).tap do |adapter|
        adapter.sponsored_benefit = sponsored_benefit
        adapter.pipeline = []
      end
    end

    it 'treats regex metacharacters in the search text as literal text' do
      expect(Person).to receive(:where).with(hash_including(:"$or" => [{first_name: /Jo\(/i}, {last_name: /Jo\(/i}])).and_call_original
      expect { subject.search_collection("Jo(") }.not_to raise_error
    end
  end
end
