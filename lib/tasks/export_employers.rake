# frozen_string_literal: true

#RAILS_ENV=production bundle exec rake employers:export

require 'csv'

namespace :employers do
  desc "Export employers to csv."
  # Usage rake employers:export
  task :export => [:environment] do
    include Config::AcaHelper

    organizations = ::BenefitSponsors::Organizations::Organization.all.employer_profiles

    file_name = fetch_file_format('employer_export','EMPLOYEREXPORT')

    def single_product?(package)
      return nil if package.blank?

      package.plan_option_kind == "single_product"
    end

    def published_on(application)
      return nil if application.blank? || application.workflow_state_transitions.blank?

      application.workflow_state_transitions.where(:event.in => ["approve_application", "approve_application!", "publish", "force_publish", "publish!", "force_publish!"]).first.try(:transition_at)
    end

    def is_pvp(application, reference_product)
      return '' unless reference_product

      rating_area_code = application.recorded_rating_area.exchange_provided_code
      reference_product.is_pvp_in_rating_area(rating_area_code, application.start_on.to_date)
    end

    def import_to_csv(csv, profile, package = nil, sponsored_benefit = nil, application = nil)
      primary_ol = profile.primary_office_location
      primary_address = primary_ol.address if primary_ol

      mailing_address = profile.office_locations.where(:"address.kind" => "mailing").first.try(:address)

      if package.present? && sponsored_benefit.present?
        contribution_levels = sponsored_benefit.sponsor_contribution.contribution_levels
        reference_product = sponsored_benefit.reference_product
        application = package.benefit_application

        if contribution_levels.size > 2
          employee_cl = contribution_levels.where(display_name: /Employee/i).first
          spouse_cl = contribution_levels.where(display_name: /Spouse/i).first
          domestic_partner_cl = contribution_levels.where(display_name: /Domestic Partner/i).first
          child_under_26_cl = contribution_levels.where(display_name: /Child Under 26/i).first
        else
          employee_cl = contribution_levels.where(display_name: /Employee Only/i).first
          spouse_cl = domestic_partner_cl = child_under_26_cl = contribution_levels.where(display_name: /Family/i).first
        end

        benefit_sponsorship = application.benefit_sponsorship
      end

      benefit_sponsorship ||= profile.active_benefit_sponsorship

      if assigned_contribution_model = sponsored_benefit&.contribution_model
        flexible_contributions_enabled  = (assigned_contribution_model.key.to_s == 'zero_percent_sponsor_fixed_percent_contribution_model') ? true : false
      end

      broker_account = benefit_sponsorship.broker_agency_accounts.first
      broker_role = broker_account.broker_agency_profile.primary_broker_role if broker_account.present?

      staff_role = profile.staff_roles.detect {|person| person.user.present? }

      csv << [
        profile.legal_name,
        profile.dba,
        profile.fein,
        profile.hbx_id,
        profile.entity_kind,
        profile.sic_code,
        profile.profile_source,
        profile.referred_by,
        profile.referred_reason,
        benefit_sponsorship.aasm_state,
        "", # GA related TODO for DC
        "", # GA related TODO for DC
        "", # GA related TODO for DC
        primary_ol.try(:is_primary),
        primary_address.try(:address_1),
        primary_address.try(:address_2),
        primary_address.try(:city),
        primary_address.try(:state),
        primary_address.try(:zip),
        mailing_address.try(:address_1),
        mailing_address.try(:address_2),
        mailing_address.try(:city),
        mailing_address.try(:state),
        mailing_address.try(:zip),
        application.try(:recorded_rating_area).try(:exchange_provided_code),
        primary_ol.try(:phone).try(:full_phone_number),
        staff_role.try(:full_name),
        staff_role.try(:work_phone_or_best),
        staff_role.try(:work_email_or_best),
        employee_cl.try(:is_offered),
        employee_cl.try(:contribution_pct),
        spouse_cl.try(:is_offered),
        spouse_cl.try(:contribution_pct),
        domestic_partner_cl.try(:is_offered),
        domestic_partner_cl.try(:contribution_pct),
        child_under_26_cl.try(:is_offered),
        child_under_26_cl.try(:contribution_pct),
        false, # child_over_26_cl.is_offered
        0, # child_over_26_cl.contribution_pct
        package.try(:title),
        package.try(:plan_option_kind),
        reference_product.try(:issuer_profile).try(:abbrev),
        reference_product.try(:metal_level),
        single_product?(package),
        reference_product.try(:title),
        is_pvp(application, reference_product),
        package.try(:effective_on_kind),
        package.try(:effective_on_offset),
        application.try(:start_on),
        application.try(:end_on),
        application.try(:open_enrollment_start_on),
        application.try(:open_enrollment_end_on),
        application.try(:fte_count),
        application.try(:pte_count),
        application.try(:msp_count),
        application.try(:aasm_state),
        published_on(application),
        broker_role.try(:broker_agency_profile).try(:npn),
        broker_account.try(:broker_agency_profile).try(:legal_name),
        broker_role.try(:person).try(:full_name),
        broker_role.try(:npn),
        broker_account.try(:start_on),
        flexible_contributions_enabled || ''
      ]
    end

    CSV.open(file_name, "w") do |csv|

      headers = %w[employer.legal_name employer.dba employer.fein employer.hbx_id employer.entity_kind employer.sic_code employer_profile.profile_source employer.referred_by employer.referred_reason employer.status ga_fein ga_agency_name ga_start_on
                   office_location.is_primary office_location.address.address_1 office_location.address.address_2
                   office_location.address.city office_location.address.state office_location.address.zip mailing_location.address_1 mailing_location.address_2 mailing_location.city mailing_location.state mailing_location.zip, employer.rating_area,
                   office_location.phone.full_phone_number staff.name staff.phone staff.email
                   employee offered spouce offered domestic_partner offered child_under_26 offered child_26_and_over
                   offered benefit_group.title benefit_group.plan_option_kind
                   benefit_group.carrier_for_elected_plan benefit_group.metal_level_for_elected_plan benefit_group.single_plan_type?
                   benefit_group.reference_plan.name benefit_group.reference_plan.is_pvp benefit_group.effective_on_kind benefit_group.effective_on_offset
                   plan_year.start_on plan_year.end_on plan_year.open_enrollment_start_on plan_year.open_enrollment_end_on
                   plan_year.fte_count plan_year.pte_count plan_year.msp_count plan_year.status plan_year.publish_date broker_agency_account.corporate_npn broker_agency_account.legal_name
                   broker.name broker.npn broker.assigned_on flexible_contributions_enabled]
      csv << headers

      puts "No general agency profile for CCA Employers" unless general_agency_enabled?

      organizations.no_timeout.each do |organization|

        profile = organization.employer_profile

        applications = profile.benefit_applications
        if applications.present?
          applications.each do |application|
            packages = application.benefit_packages
            if packages.present?
              packages.each do |package|
                package.sponsored_benefits.each do |sponsored_benefit|
                  import_to_csv(csv, profile, package, sponsored_benefit, application)
                end
              end
            else
              import_to_csv(csv, profile, nil, nil, application)
            end
          end
        else
          import_to_csv(csv, profile)
        end
      rescue Exception => e
        puts "ERROR: #{organization.legal_name} " + e.message

      end

    end

    if Rails.env.production? && Settings.site.key == :cca
      pubber = Publishers::Legacy::EmployerExportPublisher.new
      pubber.publish URI.join("file://", file_name)
    end

    puts "Output written to #{file_name}"
    puts "************ Report Finished *********"

  end
end
