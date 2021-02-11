# frozen_string_literal: true

module Config
  module AcaConcern
    def aca_qle_period
      Settings.aca.qle.with_in_sixty_days
    end

    def aca_state_abbreviation
      Settings.aca.state_abbreviation
    end

    def aca_shop_market_cobra_enrollment_period_in_months
      Settings.aca.shop_market.cobra_enrollment_period.months
    end

    def individual_market_is_enabled?
      Settings.aca.market_kinds.include? 'individual'
    end

    def general_agency_is_enabled?
      Settings.aca.general_agency_enabled
    end
  end
end
