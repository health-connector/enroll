# frozen_string_literal: true

FactoryBot.define do
  factory :ach_record do
    routing_number { '123456789' }
    bank_name { 'GNB' }
  end

end
