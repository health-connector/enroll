class FindImmediateFamilyCoverageHousehold
    include Interactor

    before do
        unless context.primary_family.present?
            context.fail!(message: "missing person id in params")
        end
    end

    def call
        immediate_family_coverage_household = family.active_household.immediate_family_coverage_household

        if immediate_family_coverage_household
            context.immediate_family_coverage_household = immediate_family_coverage_household
        else
            context.fail!(message: "no immediate_family_coverage_household for this family")
        end
    rescue StandardError => e
        context.fail!(message: "invalid ID")
    end
end