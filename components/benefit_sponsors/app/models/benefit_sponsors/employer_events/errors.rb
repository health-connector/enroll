# frozen_string_literal: true

module BenefitSponsors
  module EmployerEvents
    module Errors
      class NoCarrierPlanYearsInEvent < StandardError
      end

      class EmployerPlanYearNotFound < StandardError
      end

      class EmployerNotFound < StandardError
      end

      class PlanYearDateMismatch < StandardError
      end

      class UpstreamPlanYearOverlap < StandardError
      end
    end
  end
end
