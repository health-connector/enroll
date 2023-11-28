# frozen_string_literal: true

module BenefitSponsors
  module Validators
    module BenefitApplications
      class BenefitApplicationItemContract < Dry::Validation::Contract

        params do
          required(:effective_period).filled(type?: Range)
          required(:sequence_id).filled(:integer)
          optional(:item_type).maybe(:symbol)
          optional(:item_type_reason).maybe(:string)
          optional(:updated_by).maybe(:string)
          optional(:current_state).maybe(:symbol)
        end
      end
    end
  end
end
