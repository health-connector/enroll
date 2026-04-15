# frozen_string_literal: true

require 'active_support/inflector'
require 'dry-struct'
require 'dry-validation'

# Main Eligible module
module Eligible
  autoload :Types, 'eligible/types'
  
  # Entities namespace to avoid collision with Mongoid models
  module Entities
    autoload :TimeStamp, 'eligible/entities/time_stamp'
    autoload :StateHistory, 'eligible/entities/state_history'
    autoload :Value, 'eligible/entities/value'
    autoload :Grant, 'eligible/entities/grant'
    autoload :Evidence, 'eligible/entities/evidence'
    autoload :Eligibility, 'eligible/entities/eligibility'
  end

  # Contracts
  module Contracts
    autoload :Contract, 'eligible/contracts/contract'
    autoload :TimeStampContract, 'eligible/contracts/time_stamp_contract'
    autoload :StateHistoryContract, 'eligible/contracts/state_history_contract'
    autoload :ValueContract, 'eligible/contracts/value_contract'
    autoload :EvidenceContract, 'eligible/contracts/evidence_contract'
    autoload :GrantContract, 'eligible/contracts/grant_contract'
    autoload :EligibilityContract, 'eligible/contracts/eligibility_contract'
  end

  # Operations
  module Operations
    autoload :StateChangeValidator, 'eligible/operations/state_change_validator'
    autoload :CreateEligibilityType, 'eligible/operations/create_eligibility_type'
    autoload :AddEligibility, 'eligible/operations/add_eligibility'
  end
end
