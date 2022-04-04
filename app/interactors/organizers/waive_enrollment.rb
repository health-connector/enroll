# frozen_string_literal: true

module Organizers
  class WaiveEnrollment
    include Interactor::Organizer

    organize [
      FindEnrollment,
      ConstructWaiverEnrollment,
      TriggerWaive
]
  end
end