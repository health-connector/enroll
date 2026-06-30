# frozen_string_literal: true

module Eligible
  module Contracts
    # Contract for Value
    class ValueContract < Dry::Validation::Contract
      params do
        required(:title).filled(:string)
        required(:key).filled(:string)
      end
    end
  end
end
