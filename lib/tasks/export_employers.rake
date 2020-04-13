require 'csv'

namespace :export do
  desc "Export employers to csv."
  # Usage RAILS_ENV=production bundle exec rake export:employers
  task :employers => [:environment] do
    include Config::AcaHelper

    organizations = ::BenefitSponsors::Organizations::Organization.all.employer_profiles

    file_name = fetch_file_format('employer_export','EMPLOYEREXPORT')

    def single_product?(package)
      return nil if package.blank?
      package.plan_option_kind == "single_product"
    end

    def published_on(application)
      return nil if application.blank? || application.workflow_state_transitions.blank?
      application.workflow_state_transitions.where(:"event".in => ["approve_application", "approve_application!", "publish", "force_publish", "publish!", "force_publish!"]).first.try(:transition_at)
    end

    def rating_area_code(application)
      return nil if application.blank? || application.recorded_rating_area.blank?
      application.recorded_rating_area.exchange_provided_code
    end

    def export_group_size_count(package)
      return 0 if package.blank? || package.health_sponsored_benefit.latest_pricing_determination.blank?
      bs = package.benefit_application.benefit_sponsorship
      if bs.source_kind == :conversion || bs.source_kind == :mid_plan_year_conversion
        return nil
      else
        package.health_sponsored_benefit.latest_pricing_determination.group_size unless use_simple_employer_calculation_model?
      end
    end

    def export_participation_rate(package)
      return 0 if package.blank? || package.health_sponsored_benefit.latest_pricing_determination.blank? 
      bs = package.benefit_application.benefit_sponsorship
      if bs.source_kind == :conversion || bs.source_kind == :mid_plan_year_conversion
        return nil
      else
        package.health_sponsored_benefit.latest_pricing_determination.participation_rate unless use_simple_employer_calculation_model?
      end
    end

    def composite_premiums(package)
      initial_premium = ["", "", "", ""]
      final_premium = ["", "", "", ""]
      return initial_premium,final_premium if package.blank? || package.health_sponsored_benefit.latest_pricing_determination.blank?
      pdt = package.health_sponsored_benefit.latest_pricing_determination.pricing_determination_tiers 
      employee_premium = pdt.select{|employee_tier| employee_tier.display_name == "Employee Only"}.first.price
      employee_and_spouse = pdt.select{|employee_tier| employee_tier.display_name == "Employee and Spouse"}.first.price
      employee_and_one_or_more_dependents = pdt.select{|employee_tier| employee_tier.display_name == "Employee and Dependents"}.first.price 
      family = pdt.select{|employee_tier| employee_tier.display_name == "Family"}.first.price
      initial_premium = [employee_premium, employee_and_spouse, employee_and_one_or_more_dependents,  family]
      final_premium = initial_premium if [:active, :enrolled].include? package.benefit_application.aasm_state
      return initial_premium,final_premium
    end

    def renewal_plan_rates_flag(application)
      return nil if application.blank?
      renewal_plan_rates_exists = application.predecessor_id.present?? true : false
      return renewal_plan_rates_exists
    end

    def composite_premium_percentage(package)
      return ["", "", "", "", ""] if package.blank?
      sb = package.health_sponsored_benefit # Only Health in CCA
      health_contribution_levels = sb.sponsor_contribution.contribution_levels
      if health_contribution_levels.size > 2
        employee_cl = health_contribution_levels.where(display_name: /Employee/i).first.contribution_factor * 100
        spouse_cl = health_contribution_levels.where(display_name: /Spouse/i).first.contribution_factor * 100
        domestic_partner_cl = health_contribution_levels.where(display_name: /Domestic Partner/i).first.contribution_factor * 100
        child_under_26_cl = health_contribution_levels.where(display_name: /Child Under 26/i).first.contribution_factor * 100
        family = "N/A"
      else
        employee_cl = health_contribution_levels.where(display_name: /Employee Only/i).first.contribution_factor * 100
        spouse_cl = domestic_partner_cl = child_under_26_cl = "N/A" #Not applicable when plan is :single_product
        family = health_contribution_levels.where(display_name: /Family/i).first.contribution_factor * 100
      end
      return [employee_cl, spouse_cl, domestic_partner_cl, child_under_26_cl, family]
    end

    def rate_basis_type(package)
      cpp = composite_premium_percentage(package)

      return nil if package.blank? || cpp.blank?
      if cpp[4] != "N/A"
        return "family" 
      elsif cpp[4] == "N/A"
        return "ee-child"
      elsif cpp[3] == 0
        return "ee-spouse"
      elsif cpp[4] == 0 || (cpp[1] == 0 && cpp[2] == 0 && cpp[3] == 0)
        return "ee-only"
      end
    end

    def import_to_csv(csv, profile, package=nil)
      primary_ol = profile.primary_office_location
      primary_address = primary_ol.address if primary_ol

      mailing_address = profile.office_locations.where(:"address.kind" => "mailing").first.try(:address)

      if package.present? && package.health_sponsored_benefit.present?
        sb = package.health_sponsored_benefit # Only Health in CCA
        health_contribution_levels = sb.sponsor_contribution.contribution_levels
        reference_product = sb.reference_product
        application = package.benefit_application

        if health_contribution_levels.size > 2
          employee_cl = health_contribution_levels.where(display_name: /Employee/i).first
          spouse_cl = health_contribution_levels.where(display_name: /Spouse/i).first
          domestic_partner_cl = health_contribution_levels.where(display_name: /Domestic Partner/i).first
          child_under_26_cl = health_contribution_levels.where(display_name: /Child Under 26/i).first
        else
          employee_cl = health_contribution_levels.where(display_name: /Employee Only/i).first
          spouse_cl = domestic_partner_cl = child_under_26_cl = health_contribution_levels.where(display_name: /Family/i).first
        end

        benefit_sponsorship = application.benefit_sponsorship
        broker_account = benefit_sponsorship.broker_agency_accounts.first
        broker_role = broker_account.broker_agency_profile.primary_broker_role if broker_account.present?
      end

      benefit_sponsorship ||= profile.active_benefit_sponsorship
      broker_account ||= benefit_sponsorship.broker_agency_accounts.first
      broker_role ||= broker_account.broker_agency_profile.primary_broker_role if broker_account.present?

      staff_role = profile.staff_roles.detect {|person| person.user.present? }
      intial_tier, final_tier = composite_premiums(package)
      similar_params = [reference_product.try(:issuer_profile_id),
      reference_product.try(:metal_level),
      single_product?(package),
      reference_product.try(:title),
      package.try(:effective_on_kind),
      package.try(:effective_on_offset),
      package.try(:start_on),
      package.try(:end_on),
      package.try(:open_enrollment_start_on),
      package.try(:open_enrollment_end_on),
      renewal_plan_rates_flag(application),
      application.try(:fte_count),
      application.try(:pte_count),
      application.try(:msp_count),
      application.try(:aasm_state),
      published_on(application),
      broker_role.try(:broker_agency_profile).try(:npn),
      broker_account.try(:broker_agency_profile).try(:legal_name),
      broker_role.try(:person).try(:full_name),
      broker_role.try(:npn), 
      broker_account.try(:start_on)]

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
        primary_address.try(:county),
        mailing_address.try(:address_1),
        mailing_address.try(:address_2),
        mailing_address.try(:city),
        mailing_address.try(:state),
        mailing_address.try(:zip),
        mailing_address.try(:county),
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
        export_group_size_count(package),
        export_participation_rate(package),
        rate_basis_type(package),
        rating_area_code(application)] + intial_tier + final_tier + composite_premium_percentage(package) + similar_params
    end

    CSV.open(file_name, "w") do |csv|

      headers = %w(employer.legal_name employer.dba employer.fein employer.hbx_id employer.entity_kind 
                    employer.sic_code employer_profile.profile_source employer.referred_by employer.referred_reason 
                    employer.status ga_fein ga_agency_name ga_start_on office_location.is_primary office_location.address.address_1 
                    office_location.address.address_2 office_location.address.city office_location.address.state office_location.address.zip
                    office_location.address.county mailing_location.address_1 mailing_location.address_2 mailing_location.city
                    mailing_location.state mailing_location.zip mailing_location.county office_location.phone.full_phone_number
                    staff.name staff.phone staff.email employee offered spouce offered domestic_partner offered child_under_26
                    offered child_26_and_over offered benefit_group.title benefit_group.plan_option_kind export_group_size_count
                    export_participation_rate rate_basis_type rating_area_code estimated_composite_premium.Employee_Only
                    estimated_composite_premium.Employee_Spouse estimated_composite_premium.Employee_Children estimated_composite_premium.Family 
                    final_composite_premium.Employee_Only final_composite_premium.Employee_Spouse final_composite_premium.Employee_Children 
                    final_composite_premium.Family composite_premium_percentage.Employee composite_premium_percentage.Spouse 
                    composite_premium_percentage.Domestic_Partner composite_premium_percentage.Child_Under_26 composite_premium_percentage.Family 
                    benefit_group.carrier_for_elected_plan benefit_group.metal_level_for_elected_plan benefit_group.single_plan_type? 
                    benefit_group.reference_plan.name benefit_group.effective_on_kind benefit_group.effective_on_offset plan_year.start_on 
                    plan_year.end_on plan_year.open_enrollment_start_on plan_year.open_enrollment_end_on Renewal_plan_year_rates plan_year.fte_count 
                    plan_year.pte_count plan_year.msp_count plan_year.status plan_year.publish_date broker_agency_account.corporate_npn 
                    broker_agency_account.legal_name broker.name broker.npn broker.assigned_on)

      csv << headers

      puts "No general agency profile for CCA Employers" unless general_agency_enabled?

      organizations.no_timeout.each do |organization|
        begin
          profile = organization.employer_profile

          packages = profile.benefit_applications.map(&:benefit_packages).flatten

          if packages.present?
            packages.each do |package|
              import_to_csv(csv, profile, package)
            end
          else
            import_to_csv(csv, profile)
          end
        rescue Exception => e
          puts "ERROR: #{organization.legal_name} " + e.message
        end
      end

    end

    if Rails.env.production?
      pubber = Publishers::Legacy::EmployerExportPublisher.new
      pubber.publish URI.join("file://", file_name)
    end

    puts "Output written to #{file_name}"
    puts "************ Report Finished *********"

  end
end
