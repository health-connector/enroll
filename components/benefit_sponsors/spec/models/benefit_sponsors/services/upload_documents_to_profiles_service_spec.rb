# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::Services::UploadDocumentsToProfilesService do
  describe '#commission_statement_exist?' do
    let(:statement_date) { Date.new(2026, 10, 28) }
    let(:document) { double(title: "12345_1_10282026_COMMISSION_R.pdf") }
    let(:broker_role) { double(npn: "12345") }
    let(:broker_agency_profile) { double(primary_broker_role: broker_role, documents: double(where: [document])) }
    let(:org) { double(broker_agency_profile: broker_agency_profile) }

    it 'finds a statement with the same npn and date' do
      expect(subject.commission_statement_exist?(statement_date, org, "12345_1_10282026_COMMISSION_R.pdf")).to eq true
    end

    it 'treats regex metacharacters in the file name as literal text' do
      expect(subject.commission_statement_exist?(statement_date, org, "12345_1_.*_COMMISSION_R.pdf")).to be_falsey
    end

    it 'does not raise on an unbalanced parenthesis in the file name' do
      expect { subject.commission_statement_exist?(statement_date, org, "12345_1_(_COMMISSION_R.pdf") }.not_to raise_error
    end
  end
end
