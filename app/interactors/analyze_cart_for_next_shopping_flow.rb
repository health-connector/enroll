# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
#TODO: revisit class too complex
class AnalyzeCartForNextShoppingFlow
  include Interactor

  def call
    if context.cart.blank?
      context.cart = {}
      if context.health.present?
        context.shop_for = :health
        context.shop_attributes = context.health
      elsif context.dental.present?
        context.shop_for = :dental
        context.shop_attributes = context.dental
      end
    elsif context.cart.present? && [:health,:dental].all?{|coverage_kind| context.cart.keys.include?(coverage_kind)}
      context.go_to_coverage_selection = false
    elsif context.cart[:health].present?
      if context.dental.present?
        context.shop_for = :dental
        context.shop_attributes = context.dental
      elsif context.dental_offering == 'true'
        context.go_to_coverage_selection = true
        context.coverage_for = :dental
      elsif context.dental_offering == 'false'
        context.go_to_coverage_selection = false
      end
    elsif context.cart[:dental].present?
      if context.health.present?
        context.shop_for = :health
        context.shop_attributes = context.health
      elsif context.health_offering == 'true'
        context.go_to_coverage_selection = true
        context.coverage_for = :health
      elsif context.health_offering == 'false'
        context.go_to_coverage_selection = false
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity