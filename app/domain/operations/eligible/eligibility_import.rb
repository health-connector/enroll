# frozen_string_literal: true

require 'dry/auto_inject'

module Operations
  module Eligible
    EligibilityImport = Dry.AutoInject(EligibilityContainer)
  end
end
