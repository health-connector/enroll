# frozen_string_literal: true

module Services
  class EnrollmentService
    include ::Transcripts::EnrollmentCommon

    attr_accessor :transcript, :market, :other_enrollment

    def process
      @other_enrollment = fix_enrollment_coverage_start(@other_enrollment)
      puts "Enrollment already exist with HBX ID #{other_enrollment.hbx_id}" if HbxEnrollment.by_hbx_id(other_enrollment.hbx_id).present?
      puts 'EDI policy missing enrollees || subscriber.' if other_enrollment.hbx_enrollment_members.empty? || other_enrollment.subscriber.blank?

      message = create_enrollment
      puts message
    end

    private

    def create_enrollment
      subscriber = other_enrollment.family.primary_applicant
      matched_people = match_person_instance(subscriber.person)
      return 'Found multiple people in EA with given subscriber.' if matched_people.size > 1
      return 'Matching person not found.' if matched_people.empty?

      matched_person = matched_people.first
      employer_profile = BenefitSponsors::Organizations::Organization.employer_by_hbx_id(other_enrollment.employer_profile.hbx_id).first.employer_profile
      return 'EmployerProfile missing!' if employer_profile.blank?

      employee_role = matched_person.employee_roles.detect {|e_role| e_role.employer_profile == employer_profile}
      census_employee = find_census_employee(matched_person, employee_role, employer_profile)
      role, family = Factories::EnrollmentFactory.build_employee_role(matched_person, false, employer_profile, census_employee, census_employee.hired_on)
      employee_role ||= role


      enrollment_transcript = Importers::Transcripts::EnrollmentTranscript.new
      enrollment_transcript.other_enrollment = other_enrollment
      enrollment_transcript.market = market
      hbx_enrollment =  enrollment_transcript.send(:build_enrollment, family, employee_role, employer_profile)

      if other_enrollment.terminated_on.present?
        hbx_enrollment.update!(terminated_on: other_enrollment.terminated_on)
        hbx_enrollment.terminate_coverage!
      end

      "Success - Enrollment #{hbx_enrollment.hbx_id} added successfully using EDI source"
    rescue StandardError => e
      "Failed #{e.inspect.to_s}"
    end

    def find_census_employee(matched_person, employee_role, employer_profile)
      if employee_role.present?
        employee_role.census_employee
      else
        census_employees = CensusEmployee.matchable_terminated(matched_person.ssn, matched_person.dob).to_a
        census_employees = census_employees.select{|ce| ce.employer_profile == employer_profile}
        return "found multiple roster entrees for #{matched_person.full_name}" if census_employees.size > 1
        return 'unable to find census employee record' if census_employees.blank?
        census_employees.first
      end
    end
  end
end