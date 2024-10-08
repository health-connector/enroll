# frozen_string_literal: true

require 'rails_helper'

describe EmployerAttestationDocument, dbclean: :after_each do

  context ".submit_review" do

    let(:document) { FactoryBot.create(:employer_attestation_document) }
    let(:employer_profile) { document.employer_profile }
    let(:attestation) { document.employer_attestation }

    context '.accept' do
      it 'should accept document and approve attestation' do
        attestation.update(aasm_state: 'submitted')
        document.submit_review({status: 'accepted'})
        employer_profile.reload
        expect(document.accepted?).to be_truthy
        expect(document.employer_attestation.approved?).to be_truthy
      end
    end

    context '.reject' do
      let(:reject_reason) { "Unable To Open Document" }

      it 'should reject document and deny attestation' do
        attestation.update(aasm_state: 'submitted')
        document.submit_review({status: 'rejected', reason_for_rejection: reject_reason})
        employer_profile.reload
        expect(document.rejected?).to be_truthy
        expect(document.reason_for_rejection).to eq reject_reason
        expect(document.employer_attestation.denied?).to be_truthy
      end
    end

    context '.info_needed' do
      let(:reject_reason) { "Other Reason" }

      it 'should reject document and set pending on attestation' do
        attestation.update(aasm_state: 'submitted')
        document.submit_review({status: 'info_needed', reason_for_rejection: reject_reason, other_reason: 'info needed'})
        employer_profile.reload
        expect(document.info_needed?).to be_truthy
        expect(document.reason_for_rejection).to eq 'info needed'
        expect(document.employer_attestation.pending?).to be_truthy
      end
    end

    context 'admin approves second attestation document' do
      context 'where attestation is in denied state' do
        before :each do
          attestation.update_attributes!(aasm_state: 'denied')
          FactoryBot.create(:employer_attestation_document, employer_attestation: attestation)
          attestation.reload
        end

        it 'should change attestation status to submitted' do
          expect(attestation.submitted?).to be_truthy
        end
      end

      context 'where attestation is in approved state' do
        before :each do
          attestation.update_attributes!(aasm_state: 'approved')
          FactoryBot.create(:employer_attestation_document, employer_attestation: attestation)
        end

        it 'should not change attestation status' do
          expect(attestation.submitted?).to be_falsey
        end
      end
    end
  end
end