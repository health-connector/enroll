# frozen_string_literal: true

class FindPerson
  include Interactor

  before do
    # TODO move this to translations
    context.fail!(message: "missing person id in params") unless context.params[:person_id].present?
  end

  def call
    person = Person.find(person_id)
    if person
      context.person = person
    else
      context.fail!(message: "no person found for given id")
    end
  rescue StandardError => _e
    context.fail!(message: "invalid ID")
  end

  def person_id
    context.params[:person_id]
  end
end