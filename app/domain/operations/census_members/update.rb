# frozen_string_literal: true

require 'dry/monads'
require 'dry/monads/do'

module Operations
  module CensusMembers
    # Updates CensusMember Records
    class Update
      send(:include, Dry::Monads[:result, :do])

      VALID_RELATIONSHIP_KINDS = ["spouse", "domestic_partner", "child", "child_under_26", "child_26_and_over", "disabled_child_26_and_over"].freeze

      # @param [ Person ] person Person
      # @param [ String ] action Type of action to perform
      # @return [ BenefitSponsors::Entities::EnrollmentEligibility ] enrollment_eligibility
      def call(params)
        _validate                        = yield validate(params)
        _update_census_family            = yield update_census_family(params)
        _update_census_employee_records  = yield update_census_employee_records(params)
        _update_dependent_records        = yield update_census_dependent_records(params)
        _update_dependent_relationship   = yield update_census_dependent_relationship(params)

        Success(true)
      end

      private

      def validate(params)
        return Failure("Employee roster update feature is turned off") unless EnrollRegistry.feature_enabled?(:employee_roster_updates)

        Success(params)
      end

      def fetch_family_and_member(params)
        case params[:action]
        when 'update_census_employee'
          family = params[:person]&.primary_family
          [family, family&.find_family_member_by_person(params[:person])]
        when 'update_census_dependent'
          [params[:family_member]&.family, params[:family_member]]
        when 'update_relationship'
          family = params[:relationship]&.person&.primary_family
          [family, family&.find_family_member_by_person(params[:relationship].person)]
        end
      end

      def census_member_enrolled_under_employer?(params, employee_role)
        family, family_member = fetch_family_and_member(params)
        return false unless family.present?

        family.enrollments.where(kind: 'employer_sponsored')
              .enrolled_and_renewal
              .where(employee_role_id: employee_role.id)
              .map(&:applicant_ids).flatten.map(&:to_s).include?(family_member.id.to_s)
      end

      def update_census_family(params)
        return Success(true) unless params[:action] == 'update_census_family'

        enrollment = params[:hbx_enrollment]
        ce_person = enrollment.employee_role.person
        census_employee = enrollment.employee_role.census_employee

        # Updates census_employees
        census_employee.update_attributes(required_person_attributes_hash(ce_person, true))

        # Updates census dependents
        census_employee.census_dependents.destroy_all
        result = enrollment.hbx_enrollment_members.collect do |hbx_enrollment_member|
          person = hbx_enrollment_member.person
          next if ce_person == person

          update_census_dependent(census_employee, hbx_enrollment_member)
        end.compact

        result&.any?(&:failure) ? Failure(result.select(&:failure).map(&:failure).join(',')) : Success("Census Members are updated, enrollment: #{enrollment.hbx_id}")
      rescue StandardError => e
        Failure("Unable to create/update census dependents enrolled under hbx enrollment: #{params[:hbx_enrollment].hbx_id} due to #{e.inspect}")
      end

      def update_census_dependent(census_employee, hbx_enrollment_member)
        person = hbx_enrollment_member.person
        dependent = census_employee.census_dependents.where(first_name: person.first_name, last_name: person.last_name, dob: person.dob).first_or_create.tap do |census_dependent|
          census_dependent.gender = person.gender
          census_dependent.encrypted_ssn = person.encrypted_ssn if census_dependent.encrypted_ssn.nil?
          census_dependent.middle_name = person.middle_name
          census_dependent.name_sfx = person.name_sfx
          census_dependent.employee_relationship = build_relationship(hbx_enrollment_member.family_member)
        end
        dependent.save ? Success(true) : Failure("Unable to create/update census dependent for person #{person.hbx_id}, hbx enrollment: #{hbx_enrollment_member.hbx_enrollment.hbx_id}")
      end

      # Updates census employee with only changed attributes
      def update_census_employee_records(params)
        return Success(true) unless params[:action] == 'update_census_employee'

        result = params[:person].active_employee_roles.collect do |employee_role|
          update_record(params[:person], employee_role.census_employee, employee_role, params)
        end

        if result&.any?(&:failure)
          Failure(result.select(&:failure).map(&:failure).join(','))
        else
          Success(true)
        end
      end

      # Updates census dependent with only changed attributes
      def update_census_dependent_records(params)
        return Success(true) unless params[:action] == 'update_census_dependent'

        person = params[:person]
        return Failure("No families found, params: #{params}, action: update_census_dependent") if person.families.blank?

        employee_roles = params[:family_member].family.primary_person.active_employee_roles
        result = employee_roles.collect do |employee_role|
          census_dependent = employee_role.census_employee.census_dependents.where(matching_criteria(person)).first
          update_record(person, census_dependent, employee_role, params) if census_dependent.present?
        end

        result&.any?(&:failure) ? Failure(result.select(&:failure).map(&:failure).join(',')) : Success(true)
      end

      def update_census_dependent_relationship(params)
        relationship = params[:relationship]
        return Success(true) unless params[:action] == 'update_relationship' && VALID_RELATIONSHIP_KINDS.include?(relationship.kind)

        primary_person = relationship.person
        dependent_person = relationship.relative

        primary_person.active_employee_roles.each do |employee_role|
          employer_profile = employee_role.employer_profile
          return Success("Roster updates feature is turned off for #{employer_profile.legal_name}") unless employer_profile.enable_roster_updates

          census_dependent = employee_role.census_employee.census_dependents.where(matching_criteria(dependent_person)).first
          if census_member_enrolled_under_employer?(params, employee_role)
            census_dependent&.update_attributes(employee_relationship: fetch_relationship(relationship))
          else
            Rails.logger.info { "[Operations::CensusMembers::Update] CensusDependent: #{census_dependent.id} is NOT enrolled under #{employee_role.employer_profile.legal_name}" }
          end
        end

        Success(true)
      rescue StandardError => e
        Failure("Unable to update Employee Info Changes for person: #{primary_person.hbx_id}, action: update_relationship due to #{e.inspect}")
      end

      def update_record(person, census_member, employee_role, params)
        employer_profile = employee_role.employer_profile

        unless employer_profile.enable_roster_updates
          Rails.logger.info { "[Operations::CensusMembers::Update] Roster updates feature is turned off for #{employer_profile.legal_name}" }
          return Success("Roster updates feature is turned off for #{employer_profile.legal_name}")
        end

        unless census_member_enrolled_under_employer?(params, employee_role)
          Rails.logger.info { "[Operations::CensusMembers::Update] CensusMember: #{census_member.id} is NOT enrolled under #{employer_profile.legal_name}" }
          return Success("CensusMember: #{census_member.id} is NOT enrolled under #{employer_profile.legal_name}")
        end

        include_ssn = params[:action] == 'update_census_employee'
        census_member.update_attributes(build_updated_value_hash(person.changes, required_person_attributes(include_ssn))) if person.changed_attributes
        Success(census_member)
      rescue StandardError => e
        Failure("Unable to update Employee Info Changes for person: #{person.hbx_id}, census_member_id: #{census_member.id} due to #{e.inspect}")
      end

      def required_person_attributes(include_ssn)
        person_attributes = ['first_name', 'middle_name', 'last_name', 'name_sfx', 'dob', 'gender']
        person_attributes << 'encrypted_ssn' if include_ssn
        person_attributes
      end

      def required_person_attributes_hash(person, include_ssn)
        required_person_attributes(include_ssn).inject({}) do |attr_hash, attribute|
          attr_hash[attribute] = person.send(attribute)
          attr_hash
        end
      end

      def matching_criteria(person)
        criteria =
          {
            'first_name' => /^#{person.first_name}$/i,
            'last_name' => /^#{person.last_name}$/i,
            'dob' => person.dob
          }
        criteria.each_key do |changed_attr|
          person.changes.each do |k, v|
            next unless k == changed_attr

            criteria[changed_attr] = if ['first_name', 'last_name'].include?(k)
                                       /^#{v[0]}$/i
                                     else
                                       v[0]
                                     end
          end
        end
        criteria
      end

      def fetch_relationship(relationship)
        if relationship.kind == 'child' && relationship.relative.age_on(TimeKeeper.date_of_record) < 26
          'child_under_26'
        elsif relationship.kind == 'child'
          'child_26_and_over'
        else
          relationship.kind
        end
      end

      def build_updated_value_hash(attr_changes, req_attrs = nil)
        updated_values = { }
        attr_changes.each do |k, v|
          updated_values[k] = v[1] if req_attrs.include?(k)
        end
        updated_values
      end

      def build_relationship(family_member)
        if family_member.relationship == 'child' && family_member.person.age_on(TimeKeeper.date_of_record) < 26
          'child_under_26'
        elsif family_member.relationship == 'child'
          'child_26_and_over'
        else
          family_member.relationship
        end
      end
    end
  end
end
