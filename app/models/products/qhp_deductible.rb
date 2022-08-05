# frozen_string_literal: true

module Products
  class QhpDeductible
    include Mongoid::Document
    include Mongoid::Timestamps

    embedded_in :qhp_cost_share_variance

    # Plan deductable list
    field :deductible_type, type: String
    field :in_network_tier_1_individual, type: String
    field :in_network_tier_1_family, type: String
    field :coinsurance_in_network_tier_1, type: String

    field :in_network_tier_two_individual, type: String
    field :in_network_tier_two_family, type: String
    field :coinsurance_in_network_tier_2, type: String

    field :out_of_network_individual, type: String
    field :out_of_network_family, type: String
    field :coinsurance_out_of_network, type: String

    field :combined_in_or_out_network_individual, type: String
    field :combined_in_or_out_network_family, type: String
    field :combined_in_out_network_tier_2, type: String

    def individual
      in_network_tier_1_individual.present? ? in_network_tier_1_individual.delete('$,').to_i : 'N/A'
    end

    def family
      value = in_network_tier_1_family&.match(/[|]\s([$]\d+)/)
      value.present? ? value[1].delete('$,').to_i : 'N/A'
    end
  end
end
