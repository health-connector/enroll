module BenefitSponsors
  module SponsoredBenefits
    class SponsoredBenefit
      include Mongoid::Document
      include Mongoid::Timestamps

      SOURCE_KINDS  = [:benefit_sponsor_catalog, :conversion].freeze


      embedded_in :benefit_package,
                  class_name: "::BenefitSponsors::BenefitPackages::BenefitPackage", inverse_of: :sponsored_benefits

      field :product_package_kind,  type: Symbol
      field :product_option_choice, type: String # carrier id / metal level
      field :source_kind, type: Symbol, default: :benefit_sponsor_catalog

      belongs_to :reference_product, class_name: "::BenefitMarkets::Products::Product", inverse_of: nil

      embeds_one  :sponsor_contribution,
                  class_name: "::BenefitSponsors::SponsoredBenefits::SponsorContribution"

      embeds_many :pricing_determinations,
                  class_name: "::BenefitSponsors::SponsoredBenefits::PricingDetermination"

      delegate :contribution_model, to: :product_package, allow_nil: true
      delegate :pricing_model, to: :product_package, allow_nil: true
      delegate :pricing_calculator, to: :product_package, allow_nil: true
      delegate :contribution_calculator, to: :product_package, allow_nil: true
      delegate :recorded_rating_area, to: :benefit_package
      delegate :recorded_service_area_ids, to: :benefit_package
      delegate :rate_schedule_date, to: :benefit_package
      delegate :benefit_sponsor_catalog, to: :benefit_package
      delegate :benefit_sponsorship, to: :benefit_package
      delegate :recorded_sic_code, to: :benefit_package

      validate :product_package_exists
#      validates_presence_of :sponsor_contribution

      default_scope { where(:source_kind.ne => :conversion) }

      def product_package_exists
        if product_package.blank? && source_kind == :benefit_sponsor_catalog
          self.errors.add(:base => "Unable to find mappable product package")
        end
      end

      def product_kind
        self.class.name.demodulize.split('SponsoredBenefit')[0].downcase.to_sym
      end

      # Don't remove this. Added it to get around mass assignment
      def kind=(kind)
        # do nothing
      end

      def health?
        product_kind == :health
      end

      def single_plan_type?
        product_package_kind == :single_product
      end

      def products(coverage_date)
        lookup_package_products(coverage_date)
      end

      def lookup_package_products(coverage_date)
        return [reference_product] if product_package_kind == :single_product
        BenefitMarkets::Products::Product.by_coverage_date(product_package.products_for_plan_option_choice(product_option_choice).by_service_areas(recorded_service_area_ids), coverage_date)
      end

      def product_package
        return nil if self.product_package_kind.blank?
        @product_package ||= benefit_sponsor_catalog.product_package_for(self)
      end

      # Changing the package kind should clear the package
      def product_package_kind=(pp_kind)
        if pp_kind != self.product_package_kind
          @product_package = nil
          write_attribute(:product_package_kind, pp_kind)
        end
      end

      def issuers_offered
        return [] if products(benefit_package.start_on).blank?

        products(benefit_package.start_on).map(&:issuer_profile_id).uniq
      end

      def latest_pricing_determination
        pricing_determinations.sort_by(&:created_at).last
      end

      def renewal_product
        reference_product.renewal_product
      end

      def renewal_product_option_choice
        product_package_kind == :single_issuer ? renewal_product.issuer_profile_id.to_s : product_option_choice
      end

      def can_renew?(renewal_effective_date)
        return false if renewal_product.nil?

        renewal_product.premium_tables
                       .effective_period_cover(renewal_effective_date)
                       .present?
      end

      def renew(new_benefit_package)
        new_benefit_sponsor_catalog = new_benefit_package.benefit_sponsor_catalog
        new_product_package = new_benefit_sponsor_catalog.product_package_for(self)
        return unless new_product_package.present? && reference_product.present? && renewal_product.present? && new_product_package.active_products.include?(renewal_product)

        new_sponsored_benefit = self.class.new(
          product_package_kind: product_package_kind,
          product_option_choice: renewal_product_option_choice,
          reference_product: renewal_product,
          sponsor_contribution: sponsor_contribution.renew(new_product_package),
          benefit_package: new_benefit_package
          # pricing_determinations: renew_pricing_determinations(new_product_package)
        )
        renew_pricing_determinations(new_sponsored_benefit)
        new_sponsored_benefit
      end

      def renew_pricing_determinations(new_sponsored_benefit)
        cost_estimator = BenefitSponsors::SponsoredBenefits::CensusEmployeeCoverageCostEstimator.new(new_sponsored_benefit.benefit_sponsorship, new_sponsored_benefit.benefit_package.benefit_application.effective_period.min)
        _sbenefit, _price, _cont = cost_estimator.calculate(new_sponsored_benefit, new_sponsored_benefit.reference_product, new_sponsored_benefit.product_package, build_new_pricing_determination: true)
      end

      def reference_plan_id=(product_id)
        self.reference_product_id = product_id
      end

      def sponsor_contribution_attributes=(sponsor_contribution_attrs)
        # build_sponsor_contribution(sponsor_contribution_attrs)
      end
    end
  end
end
