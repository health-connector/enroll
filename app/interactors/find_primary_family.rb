class FindPrimaryFamily
    include Interactor

    before do
        unless context.person.present?
            context.fail!(message: "missing person")
        end
    end

    def call
       context.primary_family =  context.person.primary_family
    end
end