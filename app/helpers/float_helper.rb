# frozen_string_literal: true

module FloatHelper
  def float_fix(float_number)
    BigDecimal(float_number.to_s).round(8).to_f if float_number.present?
  end
end
