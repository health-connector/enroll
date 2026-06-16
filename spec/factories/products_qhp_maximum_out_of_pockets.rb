# frozen_string_literal: true

FactoryBot.define do
  factory :products_qhp_maximum_out_of_pocket, :class => 'Products::QhpMaximumOutOfPocket' do
    in_network_tier_1_individual_amount { "$2,000.00" }
  end

end
