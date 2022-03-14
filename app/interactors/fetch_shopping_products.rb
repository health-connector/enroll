# frozen_string_literal: true

class FetchShoppingProducts
  include Interactor

  def call
    return  if @context.shop_for.nil? && @context.go_to_coverage_selection == false
    sponsored_cost_calculator = HbxEnrollmentSponsoredCostCalculator.new(hbx_enrollment)
    sponsored_benefit = hbx_enrollment.sponsored_benefit
    rate_schedule_date = sponsored_benefit.rate_schedule_date
    products = sponsored_benefit.products(rate_schedule_date)

    # Fetch actual products from benefit market
    products = ::BenefitMarkets::Products::Product.find(products.map(&:id))
    context.member_groups = sort_member_groups(sponsored_cost_calculator.groups_for_products(products))
    context.products = context.member_groups.map(&:group_enrollment).map(&:product)

    fetch_plan_details
  end

  def fetch_plan_details
    case coverage_kind
    when 'health'
      context.metal_levels = context.products.map(&:metal_level).uniq
      context.plan_types = context.products.map(&:product_type).uniq
    when 'dental'
      context.metal_levels = context.products.map(&:metal_level).uniq
      context.plan_types = context.products.map(&:product_type).uniq
    else
      context.plan_types = []
      context.metal_levels = []
    end
  end

  def hbx_enrollment
    context.hbx_enrollment
  end

  def coverage_kind
    context.coverage_kind
  end

  def sort_member_groups(member_groups)
    member_groups.select { |member_group| member_group.group_enrollment.product.id.to_s == context.enrolled_hbx_enrollment_plan_ids.first.to_s } +
      member_groups.reject { |member_group| member_group.group_enrollment.product.id.to_s == context.enrolled_hbx_enrollment_plan_ids.first.to_s }
                   .sort_by { |mg| (mg.group_enrollment.product_cost_total - mg.group_enrollment.sponsor_contribution_total) }
  end
end