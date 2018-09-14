require 'rails_helper'

describe EmployerAttestationDocument, dbclean: :after_each do

  context ".submit_review" do

    let!(:employer_profile) { FactoryGirl.create(:benefit_sponsors_organizations_aca_shop_cca_employer_profile, :with_organization_and_site) }
    let!(:document) {FactoryGirl.build(:employer_attestation_document)}
    let!(:attestation) { FactoryGirl.build(:employer_attestation, employer_attestation_documents: [document]) }
    let!(:profile_update) { employer_profile.employer_attestation = attestation }

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
    
    context 'when employer attestation is already denied' do
      context 'admin approves second attestation document ' do 

        it 'should not change doc status and attestation status' do
          attestation.update(aasm_state: 'denied')
          document.submit_review({status: 'accepted'})
          employer_profile.reload
          expect(document.submitted?).to be_truthy
          expect(document.employer_attestation.denied?).to be_truthy
        end
      end
    end
  end
end