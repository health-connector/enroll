module BenefitSponsors
  class Enrollments::GroupEnrollment
    include ActiveModel::Model

    attr_accessor :coverage_start_on, :product, :previous_product,
                  :product_cost_total, :benefit_sponsor,
                  :sponsor_contribution_total, :member_enrollments, :group_id,
                  :rating_area, :is_pvp_eligible,
                  :rate_schedule_date, :sponsor_contribution_prohibited,
                  :medical_individual_deductible,
                  :medical_family_deductible,
                  :rx_individual_deductible,
                  :rx_family_deductible

    def initialize(opts = {})
      @group_id                   = nil
      @coverage_start_on          = nil
      @product                    = nil
      @previous_product           = nil

      @product_cost_total         = 0.00

      @benefit_sponsor            = nil
      @sponsor_contribution_total = 0.00

      @medical_individual_deductible = 0
      @medical_family_deductible     = 0
      @rx_individual_deductible      = 0
      @rx_family_deductible          = 0
      @member_enrollments         = []
      @rate_schedule_date = nil
      @rating_area = nil
      @is_pvp_eligible = false
      super(opts)
    end

    def remove_members_by_id!(member_id_list)
      @member_enrollments = @member_enrollments.reject do |m_en|
        member_id_list.include?(m_en.member_id)
      end
      self
    end

    def clone_for_coverage(new_product)
      self.class.new({
        group_id: @group_id,
        coverage_start_on: @coverage_start_on,
        benefit_sponsor: @benefit_sponsor,
        previous_product: @previous_product,
        product: new_product,
        rate_schedule_date: @rate_schedule_date,
        medical_individual_deductible: new_product&.medical_individual_deductible,
        medical_family_deductible: new_product&.medical_family_deductible,
        rx_individual_deductible: new_product&.rx_individual_deductible,
        rx_family_deductible: new_product&.rx_family_deductible,
        rating_area: @rating_area,
        is_pvp_eligible: is_pvp?(new_product),
        member_enrollments: member_enrollments.map(&:clone_for_coverage),
        sponsor_contribution_prohibited: @sponsor_contribution_prohibited
      })
    end

    def is_pvp?(new_product)
      return false unless ::EnrollRegistry.feature_enabled?(:premium_value_products)
      return false unless new_product.present?

      new_product.is_pvp_in_rating_area(@rating_area, @rate_schedule_date)
    end

    def employee_cost_total
      product_cost_total - sponsor_contribution_total
    end

    def as_json(params = {})
      super(except: ['product', 'previous_product']).merge({ product: product&.serializable_hash(except: 'premium_tables'), previous_product: previous_product&.serializable_hash(except: 'premium_tables') })
    end

    alias total_employee_cost employee_cost_total
    alias total_employer_contribution sponsor_contribution_total
    alias total_premium product_cost_total
  end
end
