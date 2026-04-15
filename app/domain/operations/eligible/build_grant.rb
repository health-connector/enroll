# frozen_string_literal: true

require "dry/monads"
require "dry/monads/do"

module Operations
  module Eligible
    # Operation to build a grant in support of eligibility creation
    class BuildGrant
      include Dry::Monads[:do, :result]

      # @param [Hash] opts Options to build eligibility
      # @option opts [<Symbol>]   :grant_key required
      # @option opts [<String>]   :grant_value required
      # @return [Dry::Monad] Hash
      def call(params)
        values = yield validate(params)
        grant_options = yield build(values)

        Success(grant_options)
      end

      private

      def validate(params)
        errors = []
        errors << "grant key missing" unless params[:grant_key]
        errors << "grant value missing" unless params[:grant_value]

        errors.empty? ? Success(params) : Failure(errors)
      end

      def build(values)
        grant_key = values[:grant_key]

        Success(
          {
            title: grant_key.to_s.titleize,
            key: grant_key.to_s,
            value: {
              title: grant_key.to_s.titleize,
              key: grant_key.to_s
            },
            state_histories: [
              {
                effective_on: Date.today,
                is_eligible: true,
                from_state: :initial,
                to_state: :approved,
                transition_at: DateTime.now,
                event: :approve
              }
            ]
          }
        )
      end
    end
  end
end