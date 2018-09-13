FactoryGirl.define do
  factory :employer_attestation do
    
    aasm_state "unsubmitted"

    trait :with_attestation_document do
      after :create do |employer_attestation, evaluator|

          employer_attestation_documents { [FactoryGirl.create(:employer_attestation_document, employer_attestation: employer_attestation)] }
      
      end
    end
  end
end
