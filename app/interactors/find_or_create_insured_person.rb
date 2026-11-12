# frozen_string_literal: true

class FindOrCreateInsuredPerson
  include Interactor

  def call
    user = context.user
    people = Person.match_by_id_info(
      ssn: context.ssn,
      dob: context.dob,
      last_name: context.last_name,
      first_name: context.first_name
    )
    people = narrow_to_exact_ssn_match(people) if people.count > 1

    person = nil
    is_new = nil
    case people.count
    when 1
      person = people.first
      user&.save
      person.user = user if user
      if person.ssn.nil?
        #matched on last_name and dob
        person.ssn = context.ssn
        person.gender = context.gender
      end
      person.save
      user = person.user if context.role_type == User::ROLES[:consumer]
      person = person #rubocop:disable Lint/SelfAssignment
      is_new = false
    when 0
      return if context.ssn.present? && Person.where(encrypted_ssn: Person.encrypt_ssn(context.ssn)).present?

      if user.try(:person).try(:present?)
        if (user.person.first_name.downcase == context.first_name.downcase) &&
           (user.person.last_name.downcase == context.last_name.downcase) # if user enters lowercase during matching.
          person = user.person
          person.update(name_sfx: context.name_sfx,
                        middle_name: context.middle_name,
                        name_pfx: context.name_pfx,
                        ssn: context.ssn,
                        dob: context.dob,
                        gender: context.gender)
          is_new = false
        else
          context.person = nil
          context.is_new = nil
          return
        end
      else
        person = Person.create(
          user: user,
          name_pfx: context.name_pfx,
          first_name: context.first_name,
          middle_name: context.middle_name,
          last_name: context.last_name,
          name_sfx: context.name_sfx,
          ssn: context.ssn,
          no_ssn: context.no_ssn,
          dob: context.dob,
          gender: context.gender
        )
        is_new = true
      end
    else
      # what am I doing here?  More than one person had the same SSN?
      context.person = nil
      context.is_new = nil
      return
    end
    if user.present?
      user.roles << context.role_type unless user.roles.include?(context.role_type)
      user.save
      unless person.emails.count > 0
        if user.email.present?
          person.emails.build(kind: "home", address: user.email)
          person.save
        end
      end
    end
    context.person = person
    context.is_new = is_new
  end

  private

  # Person.match_by_id_info can return more than one match: an exact SSN+DOB
  # match, plus any additional people found via the name+DOB fallback (which
  # also matches unrelated people who simply share a name/DOB and have no SSN
  # on file). When an SSN was provided and exactly one of the matches has that
  # exact SSN on file, prefer that verified match instead of treating the
  # coincidental name/DOB collision as an unresolvable ambiguity.
  def narrow_to_exact_ssn_match(people)
    return people if context.ssn.blank?

    exact_ssn_matches = people.select { |person| person.encrypted_ssn == Person.encrypt_ssn(context.ssn) }
    return people unless exact_ssn_matches.size == 1

    exact_ssn_matches
  end
end
