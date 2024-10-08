# frozen_string_literal: true

FactoryBot.define do
  factory :quote_member do
    first_name { "John" }
    middle_name { "M" }
    last_name { "Taylor" }
    gender { "male" }
    dob { 30.years.ago + 1.month }
  end
end

FactoryBot.define do
  factory(:quote_spouse, {class: QuoteMember}) do
    first_name { "Suzie" }
    middle_name { "Q" }
    last_name { "Taylor" }
    gender { "female" }
    dob { 30.years.ago - 1.month }
    employee_relationship { 'spouse' }
  end
end
