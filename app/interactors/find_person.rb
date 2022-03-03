class FindPerson
    include Interactor

    before do
        unless context.params[:person_id].present?
            context.fail!(message: "missing person id in params")
        end
    end

    def call
       person =  Person.find(person_id)
       if person
        context.person = context.person
       else
        context.fail!(message: "no person found for given id")
       end
    rescue StandardError => e
       context.fail!(message: "invalid ID")
    end

    def person_id
        context.params[:person_id]
    end
end