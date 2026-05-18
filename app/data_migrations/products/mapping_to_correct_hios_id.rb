# frozen_string_literal: true

# require File.join(Rails.root, "lib/mongoid_migration_task")

module Products
  class MappingToCorrectHiosId < MongoidMigrationTask

    def migrate
      hios_id = ENV.fetch('hios_id', nil)
      feins = ENV['feins'].split(',')

      feins.each do |fein|
        process_employer_fein(fein, hios_id)
      end
    end

    private

    def process_employer_fein(fein, hios_id)
      find_organization_and_update(fein, hios_id)
    rescue StandardError => e
      puts "Error processing fein #{fein}: #{e.message}" unless Rails.env.test?
    end

    def find_organization_and_update(fein, hios_id)
      organization = find_organization(fein)
      product = find_product(organization, hios_id)
      update_sponsored_benefit(organization, product, hios_id, fein)
      update_employee_enrollments(organization, product)
    end

    def find_organization(fein)
      organization = ::BenefitSponsors::Organizations::Organization.employer_profiles.where(fein: fein).first
      raise "Issue with fein: #{fein}" unless organization.present?

      organization
    end

    def find_product(organization, hios_id)
      application = organization.employer_profile.benefit_applications.where(aasm_state: "active").first
      product = application.benefit_sponsor_catalog.product_packages.where(package_kind: "single_product").first.products.where(hios_id: hios_id).first
      raise "Could not find the product with the hios_id:#{hios_id}" unless product.present?

      product
    end

    def update_sponsored_benefit(organization, product, hios_id, fein)
      application = organization.employer_profile.benefit_applications.where(aasm_state: "active").first
      health_sponsored_benefit = application.benefit_packages.first.health_sponsored_benefit
      health_sponsored_benefit.update_attributes!(reference_product_id: product.id)
      puts "Successfully updated Employer's fein:#{fein} with its hios_id:#{hios_id}" unless Rails.env.test?
    end

    def update_employee_enrollments(organization, product)
      census_employees = organization.employer_profile.census_employees
      census_employees.each do |census_employee|
        process_census_employee(census_employee, product)
      end
    end

    def process_census_employee(census_employee, product)
      enrollments = fetch_employee_enrollments(census_employee)
      update_enrollments(census_employee, enrollments, product) if enrollments.present?
    end

    def fetch_employee_enrollments(census_employee)
      application = census_employee.employer_profile.benefit_applications.where(aasm_state: "active").first
      health_sponsored_benefit = application.benefit_packages.first.health_sponsored_benefit
      census_employee.employee_role.person.primary_family.enrollments.select{|en| en.sponsored_benefit == health_sponsored_benefit}
    rescue StandardError => e
      puts "Error retrieving enrollments for #{census_employee.full_name}: #{e.message}" unless Rails.env.test?
      nil
    end

    def update_enrollments(census_employee, enrollments, product)
      if enrollments.present?
        enrollments.each do |enrollment|
          enrollment.update_attributes!(product_id: product.id)
          puts "Successfully updated #{census_employee.full_name} enrollment with its hios_id" unless Rails.env.test?
        end
      else
        raise "Census employee: #{census_employee.full_name} does not have enrollment" unless Rails.env.test?
      end
    end
  end
end
