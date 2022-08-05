# frozen_string_literal: true

class BuildLookupTable
  include Interactor

  def call
    return if context.action == "continuous_show" && @context.shop_for.nil?

    issuer_profiles = []
    @issuer_profile_ids = context.products.map(&:issuer_profile_id).uniq
    ip_lookup_table = {}
    ::BenefitSponsors::Organizations::Organization.issuer_profiles.each do |ipo|
      if @issuer_profile_ids.include?(ipo.issuer_profile.id)
        issuer_profiles << ipo.issuer_profile
        ip_lookup_table[ipo.issuer_profile.id] = ipo.issuer_profile
      end
    end
    context.carrier_names = issuer_profiles.map(&:legal_name)
    ::Caches::CustomCache.allocate(::BenefitSponsors::Organizations::Organization, :plan_shopping, ip_lookup_table)
  end
end