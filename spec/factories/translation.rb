# frozen_string_literal: true

FactoryBot.define do
  factory :translation do
    key { "en.path.to.view" }
    value { "display value" }
  end
end
