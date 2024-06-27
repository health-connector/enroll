# frozen_string_literal: true

FactoryBot.define do
  factory :employer_attestation do
    employer_profile
    aasm_state { "unsubmitted" }

    trait :with_attestation_document do
      after :create do |employer_attestation, _evaluator|
        employer_attestation_documents { [FactoryBot.create(:employer_attestation_document, employer_attestation: employer_attestation)] } if employer_attestation.submitted?
      end
    end
  end
end
