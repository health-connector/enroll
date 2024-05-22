# frozen_string_literal: true

# This rake task used to generate dry run report for MA NFP.
# To run task: RAILS_ENV=production rake dry_run:reports:nfp start_on_date="1/1/2024"

require 'csv'

namespace :dry_run do
  namespace :reports do

    desc "deatiled, non deatiled and unassigned packge reports for NFP"
    task :nfp => :environment do

      def assign_packages(start_on_date)
        file_name = "#{Rails.root}/unnassigned_packages_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv"
        system("rm -rf #{file_name}")
        CSV.open(file_name, "w") do |csv|
          csv << ["Sponsor fein", "Sponsor legal_name", "Census_Employee", "ce id"]
          BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:benefit_applications => {:$elemMatch => {:"benefit_application_items.0.effective_period.min" => start_on_date}}).each do |ben_spon|
            process_benefit_sponsorship(ben_spon, start_on_date, csv)
          end
          puts "Unnasigned packages file created #{file_name}" unless Rails.env.test?
        end
      end

      def process_benefit_sponsorship(ben_spon, start_on_date, csv)
        ben_spon.benefit_applications.each do |bene_app|
          next unless bene_app.start_on == start_on_date && bene_app.is_renewing?

          ben_spon.census_employees.active.each do |census|
            process_census_employee(ben_spon, census, bene_app, csv)
          end
        end
      end

      def process_census_employee(ben_spon, census, bene_app, csv)
        if census.employee_role.present? && census.benefit_group_assignments.where(:benefit_package_id.in => bene_app.benefit_packages.map(&:id)).blank? && !terminated_or_rehired?(census)
          data = [ben_spon.fein, ben_spon.legal_name, census.full_name, census.id]
          csv << data
          puts "ben_spon.fein: #{ben_spon&.fein}"
        end
        puts "#{ben_spon.fein} has errors #{ben_spon.errors}" if !Rails.env.test? && ben_spon.errors.present?
      end

      def terminated_or_rehired?(census)
        ["employment_terminated", "rehired", "cobra_terminated"].include?(census.aasm_state)
      end

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/PerceivedComplexity
      def detailed_report(start_on_date)
        file_name = "#{Rails.root}/dry_run_ma_nfp_detailed_report_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv"
        field_names = ["Employer Legal Name",
                       "Employer FEIN",
                       "Employer HBX ID",
                       "#{start_on_date.prev_year.year} effective_date",
                       "#{start_on_date.prev_year.year} State",
                       "#{start_on_date.year} effective_date",
                       "#{start_on_date.year} State",
                       "First name",
                       "Last Name",
                       "Roster status",
                       "Hbx ID",
                       "#{start_on_date.prev_year.year} enrollment",
                       "#{start_on_date.prev_year.year} enrollment kind",
                       "#{start_on_date.prev_year.year} plan",
                       "#{start_on_date.prev_year.year} effective_date",
                       "#{start_on_date.prev_year.year} status",
                       "#{start_on_date.year} enrollment",
                       "#{start_on_date.year} enrollment kind",
                       "#{start_on_date.year} plan",
                       "#{start_on_date.year} effective_date",
                       "#{start_on_date.year} status",
                       "Reasons"]

        system("rm -rf #{file_name}")

        CSV.open(file_name, "w", force_quotes: true) do |csv|
          csv << field_names
          begin
            BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:benefit_applications => {:$elemMatch => {:"benefit_application_items.0.effective_period.min" => start_on_date}}).each do |ben_spon|
              ben_spon.benefit_applications.each do |ben_app|

                next unless ben_app.start_on == start_on_date && ben_app.is_renewing?

                ben_app_prev_year = ben_spon.benefit_applications.where(:'benefit_application_items.effective_period.min'.lt => start_on_date, aasm_state: :active).first
                ben_spon.census_employees.active.each do |census|
                  if census.employee_role.present?
                    family = census.employee_role.person.primary_family
                  elsif Person.by_ssn(census.ssn).present? && Person.by_ssn(census.ssn).employee_roles.select{|e| e.census_employee_id == census.id && e.is_active == true}.present?
                    person = Person.by_ssn(census.ssn).first
                    family = person.primary_family
                  end
                  if family.present?
                    ben_app_prev_year = ben_spon.benefit_applications.where(:'benefit_application_items.effective_period.min'.lt => start_on_date, aasm_state: :active).first
                    packages_prev_year = ben_app_prev_year.present? ? ben_app_prev_year.benefit_packages.map(&:id) : []
                    package_ids = packages_prev_year + ben_app.benefit_packages.map(&:id)
                    enrollments = family.active_household.hbx_enrollments.where(:sponsored_benefit_package_id.in => package_ids, :aasm_state.nin => ["shopping","coverage_canceled","coverage_expired"])
                  end

                  next unless enrollments

                  ["health", "dental"].each do |kind|
                    enrollment_prev_year = enrollments.where(coverage_kind: kind, :effective_on.lt => start_on_date).first
                    enrollment_current_year = enrollments.where(coverage_kind: kind, :effective_on => start_on_date).first
                    next unless enrollment_prev_year || enrollment_current_year

                    data = [ben_spon.profile.legal_name,
                            ben_spon.profile.fein,
                            ben_spon.profile.hbx_id,
                            ben_app_prev_year.start_on,
                            ben_app_prev_year.try(:aasm_state),
                            ben_app.start_on,
                            "renewing_#{ben_app.aasm_state}",
                            census.first_name,
                            census.last_name,
                            census.aasm_state,
                            census.try(:employee_role).try(:person).try(:hbx_id) || Person.by_ssn(census.ssn).first.hbx_id,
                            enrollment_prev_year.try(:hbx_id),
                            enrollment_prev_year.try(:coverage_kind),
                            enrollment_prev_year.try(:product).try(:hios_id),
                            enrollment_prev_year.try(:effective_on),
                            enrollment_prev_year.try(:aasm_state),
                            enrollment_current_year.try(:hbx_id),
                            enrollment_prev_year.try(:coverage_kind),
                            enrollment_current_year.try(:product).try(:hios_id),
                            enrollment_current_year.try(:effective_on),
                            enrollment_current_year.try(:aasm_state)]
                    data += [find_failure_reason(enrollment_prev_year, enrollment_current_year, ben_app)]
                    csv << data
                  end
                end
              end
            end
            puts "Successfully generated detailed_report #{file_name}" unless Rails.env.test?
          rescue StandardError => e
            puts e.to_s
          end
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/PerceivedComplexity

      def find_failure_reason(enrollment_prev_year, enrollment_current_year, ben_app)
        current_year_state = enrollment_current_year&.aasm_state
        prev_year_state = enrollment_prev_year&.aasm_state
        rp_id = fetch_product_id(enrollment_prev_year)
        cp_id = fetch_product_id(enrollment_current_year)

        case current_year_state
        when "auto_renewing"
          "Successfully Generated"
        when "coverage_enrolled"
          "The plan year was manually published by stakeholders" if ["active","enrollment_eligible"].include?(ben_app.aasm_state)
        when "coverage_selected"
          "Plan was manually selected for the current year" unless rp_id == cp_id
        when "inactive", "renewing_waived"
          "enrollment is waived"
        else
          handle_nil_current_year_state(current_year_state, prev_year_state, ben_app, rp_id, cp_id)
        end
      end

      def fetch_product_id(enrollment)
        enrollment&.product&.id
      end

      def handle_nil_current_year_state(current_year_state, prev_year_state, ben_app, rp_id, cp_id)
        return unless current_year_state.nil?

        if ben_app.aasm_state == 'pending'
          "ER zip code is not in DC"
        elsif prev_year_state.in?(HbxEnrollment::WAIVED_STATUSES + HbxEnrollment::TERMINATED_STATUSES)
          "Previous plan has waived or terminated and did not generate renewal"
        elsif ["coverage_selected", "coverage_enrolled"].include?(prev_year_state)
          "Enrollment plan was changed either for current year or previous year" unless rp_id == cp_id
        end
      end

      def non_detailed_report(start_on_date)
        file_name = "#{Rails.root}/ma_nfp_non_detailed_report_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv"
        field_names  = [
          "Employer_Legal_Name",
          "Employer_FEIN",
          "Renewal State",
          "#{start_on_date.prev_year.year} Active Enrollments",
          "#{start_on_date.prev_year.year} Passive Renewal Enrollments"
        ]
        system("rm -rf #{file_name}")

        CSV.open(file_name, "w", force_quotes: true) do |csv|
          csv << field_names
          begin
            BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:benefit_applications => {:$elemMatch => {:"benefit_application_items.0.effective_period.min" => start_on_date}}).each do |ben_spon|
              handle_benefit_sponsorship(ben_spon, start_on_date, csv)
            end
            puts "Successfully generated non_detailed_report #{file_name}" unless Rails.env.test?
          rescue StandardError => e
            puts e.to_s
          end
        end
      end

      def handle_benefit_sponsorship(ben_spon, start_on_date, csv)
        ben_spon.benefit_applications.each do |bene_app|
          next unless bene_app.start_on == start_on_date && bene_app.is_renewing?

          data =  [ben_spon.legal_name, ben_spon.fein, ben_spon.renewal_benefit_application.aasm_state.to_s.camelcase]
          next if ben_spon.renewal_benefit_application.blank?

          active_bg_ids = ben_spon.current_benefit_application.benefit_packages.pluck(:id)
          families = Family.where(:"households.hbx_enrollments" => {:$elemMatch => {:sponsored_benefit_package_id.in => active_bg_ids, :aasm_state.in => HbxEnrollment::ENROLLED_STATUSES}})
          renewal_bg_ids = ben_spon.renewal_benefit_application.benefit_packages.pluck(:id) if ben_spon.renewal_benefit_application.present?

          active_enrollment_count, renewal_enrollment_count = process_families(families, active_bg_ids, renewal_bg_ids)
          data += [active_enrollment_count, renewal_enrollment_count]
          csv << data
        end
      end

      def process_families(families, active_bg_ids, renewal_bg_ids)
        active_enrollment_count = 0
        renewal_enrollment_count = 0
        families.each do |family|
          active_enrollment_count += count_enrollments(family, active_bg_ids)
          renewal_enrollment_count += count_enrollments(family, renewal_bg_ids) if renewal_bg_ids.present?
        end
        [active_enrollment_count, renewal_enrollment_count]
      end

      def count_enrollments(family, bg_ids)
        count = 0
        enrollments = family.active_household.hbx_enrollments.where({
                                                                      :sponsored_benefit_package_id.in => bg_ids,
                                                                      :aasm_state.in => HbxEnrollment::ENROLLED_STATUSES + ['auto_renewing']
                                                                    })
        %w[health dental].each do |coverage_kind|
          count += 1 if enrollments.where(:coverage_kind => coverage_kind).present?
        end
        count
      end

      def benefit_applications_in_aasm_state(aasm_states, start_on_date)
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
          :benefit_applications =>
            { :$elemMatch =>
              {
                :"benefit_application_items.0.effective_period.min" => start_on_date,
                :predecessor_id => {"$ne" => nil},
                :aasm_state.in => aasm_states
              }}
        )
      end

      def ben_app_not_in_oe(start_on_date)
        CSV.open("#{Rails.root}/employers_not_in_renewing_enrolling_#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.csv", "w") do |csv|
          csv << ["Organization name","Organization fein","Benefit Application State"]
          benefit_applications_in_aasm_state(['draft','pending','enrollment_eligible','approved','active','termination_pending','canceled','enrollment_ineligible','enrollment_extended'], start_on_date).each do |ben_spon|
            aasm_state = ben_spon.renewal_benefit_application&.aasm_state
            data = [ben_spon.legal_name, ben_spon.fein, aasm_state]
            csv << data
          end
        end
      end

      def dry_run
        start_on_date = Date.strptime(ENV['start_on_date'], "%m/%d/%Y")
        detailed_report(start_on_date)
        assign_packages(start_on_date)
        ben_app_not_in_oe(start_on_date)
        non_detailed_report(start_on_date)
      end
      dry_run
    end
  end
end
