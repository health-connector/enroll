# ProductPackage provides the composite package for Benefits that may be purchased.  Site
# exchange Admins (or seed files) define ProductPackage settings.  Benefit Catalog accesses
# all Products via ProductPackage.
# ProductPackage functions:
# => Provides filters for benefit display
# => Instantiates a SponsoredBenefit class for inclusion in BenefitPackage
module BenefitMarkets
  class Products::ProductPackage
    include Mongoid::Document
    include Mongoid::Timestamps

    # Added this module as a temporary fix for EMPLOYER FLEXIBILITY PROJECT
    module ContributionModuleAssociation
      def contribution_model
        assigned_contribution_model || super
      end
    end

    prepend ContributionModuleAssociation

    embedded_in :packagable, polymorphic: true

    field :application_period,      type: Range
    field :benefit_kind,            type: Symbol #, default: :aca_individual  # => :aca_shop
    field :product_kind,            type: Symbol # [ :health, :dental, :etc ]
    field :package_kind,            type: Symbol # [:single_issuer, :metal_level, :single_product]
    field :title,                   type: String, default: ""
    field :description,             type: String, default: ""

    embeds_many :products,
                class_name: "BenefitMarkets::Products::Product"

    embeds_one  :contribution_model,
                class_name: "BenefitMarkets::ContributionModels::ContributionModel"

    embeds_one  :assigned_contribution_model,
                class_name: "BenefitMarkets::ContributionModels::ContributionModel"

    embeds_many :contribution_models,
                class_name: "BenefitMarkets::ContributionModels::ContributionModel"

    embeds_one  :pricing_model,
                class_name: "BenefitMarkets::PricingModels::PricingModel"

    validates_presence_of :product_kind, :benefit_kind, :package_kind, :application_period,
                          :pricing_model, :contribution_model
    validates_presence_of :title, :allow_blank => false
#    validates_presence_of :products, :allow_blank => false

    scope :by_benefit_kind,     ->(kind){ where(benefit_kind: kind) }
    scope :by_package_kind,     ->(package_kind) { where(package_kind: package_kind) }
    scope :by_product_kind,     ->(product_kind) { where(product_kind: product_kind) }

    delegate :pricing_calculator, to: :pricing_model, allow_nil: true
    delegate :contribution_calculator, to: :contribution_model, allow_nil: true

    def comparable_attrs
      [
        :application_period, :product_kind, :package_kind, :title, :description, :product_multiplicity,
        :contribution_model, :pricing_model
        ]
    end

    def products=(attributes)
      new_products =
        attributes.collect do |attribute|
          if attribute.is_a?(Hash)
            kind = attribute[:kind].to_s.titleize
            product_class = "BenefitMarkets::Products::#{kind}Products::#{kind}Product".constantize
            product_class.new(attribute)
          else
            attribute
          end
        end
      products << new_products
    end

    def lowest_cost_product(effective_date, issuer_hios_ids = nil)
      return @lowest_cost_product if defined? @lowest_cost_product

      load_filtered_products = issuer_hios_ids.present? ? load_base_products.select {|p| issuer_hios_ids.include?(p.hios_id.slice(0, 5))} : load_base_products
      @lowest_cost_product = load_filtered_products.min_by do |product|
        product.min_cost_for_application_period(effective_date)
      end
    end

    def highest_cost_product(effective_date, issuer_hios_ids = nil)
      return @highest_cost_product if defined? @highest_cost_product

      load_filtered_products = issuer_hios_ids.present? ? load_base_products.select {|p| issuer_hios_ids.include?(p.hios_id.slice(0, 5))} : load_base_products
      @highest_cost_product ||= load_filtered_products.max_by do |product|
        product.max_cost_for_application_period(effective_date)
      end
    end

    def products_sorted_by_cost
      return @products_sorted_by_cost if defined? @products_sorted_by_cost

      @products_sorted_by_cost = load_base_products.sort_by{|product|
        product.cost_for_application_period(application_period)
      }
    end

    def load_base_products
      return [] if products.empty?
      @loaded_base_products ||= BenefitMarkets::Products::Product.find(products.pluck(:_id))
    end

    # Define Comparable operator
    # If instance attributes are the same, compare Products
    def <=>(other)
      if comparable_attrs.all? { |attr| send(attr) == other.send(attr) }
        if products.to_a == other.products.to_a
          0
        else
          products.to_a <=> other.products.to_a
        end
      else
        other.updated_at.blank? || (updated_at < other.updated_at) ? -1 : 1
      end
    end

    def product_multiplicity
      if [:single_issuer, :metal_level, :multi_product].include? :package_kind
        :multiple
      else
        :single
      end
    end

    def effective_date
      packagable.effective_date || application_period.min
    end

    def benefit_market_kind
      packagable.benefit_market_kind
    end

    # Returns only products for which rates available
    def active_products
      products.effective_with_premiums_on(effective_date)
    end

    def issuer_profiles
      return @issuer_profiles if defined?(@issuer_profiles)
      @issuer_profiles = active_products.select { |product| product.issuer_profile }.uniq!
    end

    def issuer_profile_products_for(issuer_profile)
      return @issuer_profile_products if defined?(@issuer_profile_products)
      @issuer_profile_products = products.by_issuer_profile(issuer_profile)
    end

    # Load product subset the embedded .products list from BenefitMarket::Products using provided criteria
    def load_embedded_products(service_areas, effective_date)
      benefit_market_products_available_for(service_areas, effective_date).collect { |prod| prod.create_copy_for_embedding }
    end

    # Query products from database applicable to this product package
    def all_benefit_market_products
      raise StandardError, "Product package is invalid" unless benefit_market_kind.present? && application_period.present? && product_kind.present? && package_kind.present?
      return @all_benefit_market_products if defined?(@all_benefit_market_products)
      @all_benefit_market_products = BenefitMarkets::Products::Product.by_product_package(self)
    end

    # Intersection of BenefitMarket::Products that match both service area and effective date
    def benefit_market_products_available_for(service_areas, effective_date)
      service_area_ids = service_areas.map(&:id)
      all_benefit_market_products.by_service_areas(service_area_ids).effective_with_premiums_on(effective_date)
    end

    # BenefitMarket::Products available for purchase on effective date
    def benefit_market_products_available_on(effective_date)
      all_benefit_market_products.select { |product| product.premium_table_effective_on(effective_date).present? }
    end

    # BenefitMarket::Products available for purchase within a specified service area
    def benefit_market_products_available_where(service_areas)
      all_benefit_market_products.select { |product| service_areas.include?(product.service_area) }
    end

    def products_for_plan_option_choice(product_option_choice)
      if package_kind == :metal_level
        products.by_metal_level_kind(product_option_choice.to_sym)
      elsif package_kind == :multi_product
        products
      else
        issuer_profile = BenefitSponsors::Organizations::IssuerProfile.find(product_option_choice)
        return [] unless issuer_profile
        issuer_profile_products_for(issuer_profile)
      end
    end

    def add_product(new_product)
      products.push(new_product).uniq!
    end

    def drop_product(new_product)
      products.delete(new_product) { "not found" }
    end

  end
end
