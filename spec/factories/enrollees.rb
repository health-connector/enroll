# frozen_string_literal: true

FactoryBot.define do
  factory :enrollee do
    coverage_start_on { Date.today }
    person
  end
end
