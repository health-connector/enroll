# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

class AddAndRemoveEnrollmentMember < MongoidMigrationTask
  def migrate
    @enrollment_input = enrollment_input.to_s.strip
    @person_to_remove_input = person_to_remove_input.to_s.strip
    @person_to_add_input = person_to_add_input.to_s.strip
    @family = enrollment_family

    if @family
      @enrollment = @family.active_household.hbx_enrollments.where(hbx_id: @enrollment_input).first
      @family_member_id = @family.active_household.family_members.find do |fm|
        fm.person.hbx_id == @person_to_add_input
      end&.id
      fix_enrollment
    else
      abort("Aborted! Can't find any family with #{@enrollment_input} enrollment ID.") unless Rails.env.test?
    end
  end

  def fix_enrollment
    delete_enrollment_member if @person_to_remove_input.present? && @person_to_remove_input != 'skip'
    add_enrollment_member if @person_to_add_input.present? && @person_to_add_input != 'skip' && @family_member_id

    return unless @enrollment.save!

    puts "Person with hbx_id: #{@person_to_remove_input} was removed from enrollment hbx_id: #{@enrollment_input}" unless Rails.env.test?
    puts "Person with hbx_id: #{@person_to_add_input} was added to enrollment hbx_id: #{@enrollment_input}" unless Rails.env.test?
  end

  def delete_enrollment_member
    enrollment_member = @enrollment.hbx_enrollment_members.find do |em|
      em.person.hbx_id == @person_to_remove_input
    end

    return unless enrollment_member&.delete

    puts "Removed." unless Rails.env.test?
  end

  def add_enrollment_member
    @enrollment.hbx_enrollment_members.push(new_member)
    puts "Added." unless Rails.env.test?
  end

  def new_member
    HbxEnrollmentMember.new({
                              applicant_id: @family_member_id,
                              eligibility_date: @enrollment.subscriber.eligibility_date,
                              coverage_start_on: @enrollment.subscriber.coverage_start_on
                            })
  end

  def enrollment_input
    print "Provide Enrollment hbx_id: " unless Rails.env.test?
    validated_input("enrollment_input")
  end

  def person_to_remove_input
    print "Person hbx_id to REMOVE from enrollment or print 'skip': " unless Rails.env.test?
    validated_input("person_to_remove_input")
  end

  def person_to_add_input
    print "Person hbx_id to ADD to enrollment or print 'skip': " unless Rails.env.test?
    validated_input("person_to_add_input")
  end

  def validated_input(_method_name)
    loop do
      input = admin_input
      return input if confirm_input(input)


      print "Please enter the value again: " unless Rails.env.test?

    end
  end

  def admin_input
    return "test_input" if Rails.env.test?

    begin
      input = $stdin.gets.chomp.to_s.strip
      return input if input == 'skip'

      Integer(input)
      input
    rescue ArgumentError
      print "Wrong input! Hbx_id can have only numeric values. Print one more time: " unless Rails.env.test?
      retry
    end
  end

  def confirm_input(input)
    return true if Rails.env.test?

    puts "\nIs this correct input: #{input}? Y/N. 'EXIT' - to interrupt the process."
    answer = $stdin.gets.chomp.downcase

    case answer
    when 'y', 'yes'
      true
    when 'n', 'no'
      false
    when 'exit'
      abort("You've interrupted the data fix process.")
    else
      puts "Please enter Y/N or EXIT"
      confirm_input(input)
    end
  end

  def enrollment_family
    Family.where("households.hbx_enrollments.hbx_id" => @enrollment_input).first
  end
end
