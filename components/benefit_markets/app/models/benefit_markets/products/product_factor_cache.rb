# frozen_string_literal: true

module BenefitMarkets
  module Products
    # Provides a cached, efficient lookup for referencing rate values
    # by multiple keys.
    class ProductFactorCache
      # Thread-safe lazy loading
      @cache_loaded = false
      @cache_mutex = Mutex.new

      def self.ensure_cache_loaded!
        return if @cache_loaded

        @cache_mutex.synchronize do
          return if @cache_loaded

          initialize_factor_cache!
          @cache_loaded = true
        end
      end

      def self.cache_loaded?
        @cache_loaded
      end

      def self.initialize_factor_cache!
        $pf_cache_for_composite_tier_factor = {}
        $pf_cache_for_group_size = {}
        $pf_cache_for_participation_percent = {}
        $pf_cache_for_sic_code = {}
        ::BenefitMarkets::Products::ActuarialFactors::CompositeRatingTierActuarialFactor.all.each do |crtaf|
          $pf_cache_for_composite_tier_factor[[crtaf.issuer_profile_id, crtaf.active_year]] = crtaf.cacherize!
        end
        ::BenefitMarkets::Products::ActuarialFactors::GroupSizeActuarialFactor.all.each do |crtaf|
          $pf_cache_for_group_size[[crtaf.issuer_profile_id, crtaf.active_year]] = crtaf.cacherize!
        end
        ::BenefitMarkets::Products::ActuarialFactors::ParticipationRateActuarialFactor.all.each do |crtaf|
          $pf_cache_for_participation_percent[[crtaf.issuer_profile_id, crtaf.active_year]] = crtaf.cacherize!
        end
        ::BenefitMarkets::Products::ActuarialFactors::SicActuarialFactor.all.each do |crtaf|
          $pf_cache_for_sic_code[[crtaf.issuer_profile_id, crtaf.active_year]] = crtaf.cacherize!
        end
      end

      # Return the sic code factor value for a given product.
      # @param product [Product] the product for which I desire the value
      # @param sic_code [String] the SIC code
      # @return [Float, BigDecimal] the factor
      def self.lookup_sic_code_factor(
        product,
        sic_code
      )
        ensure_cache_loaded!
        $pf_cache_for_sic_code[[product.issuer_profile_id, product.active_year]].cached_lookup(sic_code)
      end

      # Return the group size factor value for a given product.
      # @param product [Product] the product for which I desire the value
      # @param group_size [String] the group size
      # @return [Float, BigDecimal] the factor
      def self.lookup_group_size_factor(
        product,
        group_size
      )
        ensure_cache_loaded!
        $pf_cache_for_group_size[[product.issuer_profile_id, product.active_year]].cached_lookup(group_size)
      end

      # Return the participation percent factor value for a given product.
      # @param product [Product] the product for which I desire the value
      # @param participation_percent [String] the participation_percent
      # @return [Float, BigDecimal] the factor
      def self.lookup_participation_percent_factor(
        product,
        participation_percent
      )
        ensure_cache_loaded!
        $pf_cache_for_participation_percent[[product.issuer_profile_id, product.active_year]].cached_lookup(participation_percent)
      end

      # Return the rating tier factor value for a given product.
      # @param product [Product] the product for which I desire the value
      # @param rating_tier_name [String] the rating_tier_name
      # @return [Float, BigDecimal] the factor
      def self.lookup_composite_tier_factor(
        product,
        tier_name
      )
        ensure_cache_loaded!
        $pf_cache_for_composite_tier_factor[[product.issuer_profile_id, product.active_year]].cached_lookup(tier_name)
      end
    end
  end
end
