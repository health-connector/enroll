module Queries
  class FamilyDatatableQuery

    attr_reader :search_string, :custom_attributes

    def datatable_search(string)
      @search_string = string
      self
    end

    def initialize(attributes)
      @custom_attributes = attributes
    end

    def person_search search_string
      return Family if search_string.blank?


    end

    def build_scope()
      #return Family if @search_string.blank?
      #person_id = Person.search(@search_string).limit(5000).pluck(:_id)
      #family_scope = Family.where('family_members.person_id' => {"$in" => person_id})
      family = Family
      person = Person

      case @custom_attributes['families']
      when 'by_enrollment_individual_market'
        family = family.by_enrollment_individual_market
        family = build_individual_scope(family)
      when 'by_enrollment_shop_market'
        family = family.by_enrollment_shop_market
        family = build_shop_scope(family)
      when 'non_enrolled'
        family = family.non_enrolled
      when 'by_enrollment_coverall'
        resident_ids = Person.all_resident_roles.pluck(:_id)
        family = family.where('family_members.person_id' => {"$in" => resident_ids})
      end

      #add other scopes here
      return family if @search_string.blank? || @search_string.length < 2
      person_id = Person.search(@search_string).pluck(:_id)
      #Caution Mongo optimization on chained "$in" statements with same field
      #is to do a union, not an interactionl
      family_scope = family.and('family_members.person_id' => {"$in" => person_id})
      return family_scope if @order_by.blank?
      family_scope.order_by(@order_by)
    end

    def build_shop_scope family
      case @custom_attributes['employer_options']
      when 'enrolled'
        family = family.all_enrollments
      when 'by_enrollment_renewing'
        family = family.by_enrollment_renewing
      when 'sep_eligible'
        family = family.sep_eligible
      when 'coverage_waived'
        family = family.coverage_waived
      else
        family = family.all_enrollments
      end
      family
    end

    def build_individual_scope family
      case @custom_attributes['individual_options']
      when 'all_assistance_receiving'
        family = family.all_assistance_receiving
      when 'sep_eligible'
        family = family.sep_eligible
      when 'all_unassisted'
        family = family.all_unassisted
      else
        family = family.all_enrollments
      end
      family
    end

    def skip(num)
      build_scope.skip(num)
    end

    def limit(num)
      build_scope.limit(num)
    end

    def order_by(var)
      @order_by = var
      self
    end

    def klass
      Family
    end

    def size
      build_scope.count
    end

  end
end
