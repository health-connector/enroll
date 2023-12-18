# frozen_string_literal: true

module BenefitSponsors
  module Validators
    module BenefitApplications
      class BenefitApplicationItemContract < Dry::Validation::Contract

        params do
          required(:effective_period).filled(type?: Range)
          required(:sequence_id).filled(:integer)
          optional(:action_type).maybe(:symbol)
          optional(:action_on).maybe(:date)
          optional(:action_kind).maybe(:string)
          optional(:action_reason).maybe(:string)
          optional(:updated_by).maybe(:string)
          optional(:state).maybe(:symbol)
        end
      end
    end
  end
end
