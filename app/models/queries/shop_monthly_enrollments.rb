module Queries
  class ShopMonthlyEnrollments
    include QueryHelpers

    attr_accessor :enrollment_statuses

    def initialize(feins, effective_on)
      @feins = feins
      @effective_on = effective_on
      @pipeline = []
    end

    def add(step)
      @pipeline << step.to_hash
    end

    def evaluate
      Family.collection.aggregate(@pipeline)
    end

    def query_families_with_quiet_period_enrollments
      # include new hire enrollment that purchased in open enrollment with effective_on date greater benefit application start date,
      # and quiet period enrollments.
      add({
        "$match" => {
          "$or" => [
            {"$and" =>[
              "households.hbx_enrollments.sponsored_benefit_id" => { "$in" => collect_benefit_group_ids },
              "households.hbx_enrollments.workflow_state_transitions" => { "$elemMatch" => quiet_period_expression }
            ]},
            {"$and" =>[
              "households.hbx_enrollments.aasm_state" => {"$in" => @enrollment_statuses},
              "households.hbx_enrollments.effective_on" => {"$gt" => @effective_on},
              "households.hbx_enrollments.sponsored_benefit_id" => { "$in" => collect_benefit_group_ids },
              "households.hbx_enrollments.submitted_at" => {"$lt" => quiet_period.begin}
            ]}
          ]
        }
      })

      self
    end

    def query_families_with_active_enrollments
       add({
        "$match" => {
          "households.hbx_enrollments.benefit_group_id" => {
            "$in" => collect_benefit_group_ids
          }
        }
      })

      self
    end

     def query_active_enrollments
      add({
        "$match" => {
          "$or" => [
            new_coverage_expression
          ]
        }
      })

      self
    end

    def query_quiet_period_enrollments
      add({
        "$match" => {
          "$or" => [
            quiet_period_coverage_expression,
            new_hire_enrollment_expression
          ]
        }
      })

      self
    end

    def query_families
      add({
        "$match" => {
          "households.hbx_enrollments.benefit_group_id" => {
            "$in" => (collect_benefit_group_ids + collect_benefit_group_ids(@effective_on.prev_year))
          }
        }
      })

      self
    end

    def unwind_enrollments
      add({"$unwind" => "$households"})
      add({"$unwind" => "$households.hbx_enrollments"})
      self
    end

    def new_enrollment_statuses
      HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES + HbxEnrollment::TERMINATED_STATUSES
    end

    def existing_enrollment_statuses
      HbxEnrollment::ENROLLED_STATUSES + HbxEnrollment::RENEWAL_STATUSES + ['coverage_expired']
    end

    def quiet_period
      # quiet period check not needed for renewal application(quiet period: OE close to 26th of month) just for initial(quiet period: OE close to 8th of next month)
      # transmission date 26th of month
      quiet_period_start = Date.new( @effective_on.prev_month.year,  @effective_on.prev_month.month, Settings.aca.shop_market.open_enrollment.monthly_end_on + 1)
      quiet_period_end =  @effective_on + (Settings.aca.shop_market.initial_application.quiet_period.month_offset.months) + (Settings.aca.shop_market.initial_application.quiet_period.mday - 1).days
      TimeKeeper.start_of_exchange_day_from_utc(quiet_period_start)..TimeKeeper.end_of_exchange_day_from_utc(quiet_period_end)
    end

    def quiet_period_expression
      {
        "to_state" => {"$in" => @enrollment_statuses},
        "transition_at" => {
          "$gte" => quiet_period.begin,
          "$lt" => quiet_period.end
        }
      }
    end

    def quiet_period_coverage_expression
      {
        "households.hbx_enrollments.sponsored_benefit_id" => { "$in" => collect_benefit_group_ids },
        "households.hbx_enrollments.kind" => {"$in" => ["employer_sponsored", "employer_sponsored_cobra"]},
        "households.hbx_enrollments.workflow_state_transitions" => { 
          "$elemMatch" => quiet_period_expression 
        }
      }
    end

    def new_hire_enrollment_expression
      {
          "households.hbx_enrollments.effective_on" => {"$gt" => @effective_on},
          "households.hbx_enrollments.sponsored_benefit_id" => { "$in" => collect_benefit_group_ids },
          "households.hbx_enrollments.kind" => {"$in" => ["employer_sponsored", "employer_sponsored_cobra"]},
          "households.hbx_enrollments.submitted_at" => {"$lt" => quiet_period.begin}
      }
    end

    def new_coverage_expression
      {
        "households.hbx_enrollments.benefit_group_id" => {"$in" => collect_benefit_group_ids},
        "households.hbx_enrollments.aasm_state" => {"$in" => new_enrollment_statuses},
        "households.hbx_enrollments.effective_on" => @effective_on,
        # Exclude COBRA, for now
        "households.hbx_enrollments.kind" => {"$in" => ["employer_sponsored", "employer_sponsored_cobra"]}
      }
    end

    def existing_coverage_expression
      {
        "households.hbx_enrollments.benefit_group_id" => {"$in" => collect_benefit_group_ids(@effective_on.prev_year)},
        "households.hbx_enrollments.aasm_state" => {"$in" => existing_enrollment_statuses},
        "households.hbx_enrollments.effective_on" => {"$gte" => @effective_on.prev_year},
        # Exclude COBRA, for now
        "households.hbx_enrollments.kind" => "employer_sponsored"
      }
    end

    def query_enrollments
      add({
        "$match" => {
          "$or" => [
            new_coverage_expression.merge!("households.hbx_enrollments.enrollment_kind" => "open_enrollment"),
            existing_coverage_expression
          ]
        }
      })

      self
    end

    def group_enrollments
      add({
        "$group" => {
          "_id" => {
            "effective_on" => "$households.hbx_enrollments.effective_on",
            "employee_role_id" => "$households.hbx_enrollments.employee_role_id",
            "bga_id" => "$households.hbx_enrollments.benefit_group_assignment_id",
            "coverage_kind" => "$households.hbx_enrollments.coverage_kind"
          },
          "hbx_enrollment_id" => {"$last" => "$households.hbx_enrollments.hbx_id"},
          "submitted_at" => {"$last" => "$households.hbx_enrollments.submitted_at"}
        }
      })

      self
    end

    def group_enrollment_events
      add({
        "$group" => {
          "_id" => "$households.hbx_enrollments.hbx_id",
          "hbx_enrollment_id" => {"$last" => "$households.hbx_enrollments.hbx_id"},
          "submitted_at" => {"$last" => "$households.hbx_enrollments.submitted_at"}
        }
      })

      self
    end

    def sort_enrollments
      add({
       "$sort" => {"households.hbx_enrollments.submitted_at" => 1}
      })
      self
    end

    def project_enrollment_ids
      add({
        "$project" => {
         "_id" => 1,
         "enrollment_hbx_id" => "$hbx_enrollment_id",
         "enrollment_submitted_at" => "$submitted_at"
        }
      })
      self
    end

    def collect_benefit_group_ids(effective_on = nil)
      @feins.collect{|e| prepend_zeros(e.to_s, 9) }.inject([]) do |id_list, fein|
        benefit_sponsorship = BenefitSponsors::Organizations::Organization.where(fein:  fein).first.active_benefit_sponsorship

        if benefit_sponsorship.present?
          benefit_application = benefit_sponsorship.benefit_applications.where(:predecessor_id => nil, :aasm_state => :active).detect { |application| application.start_on.to_date == (effective_on || @effective_on).to_date }
        end

        if benefit_application.blank?
          id_list
        else
          id_list += benefit_application.benefit_packages.map(&:sponsored_benefits).flatten.map(&:id)
        end
      end
    end

    def prepend_zeros(number, n)
      (n - number.to_s.size).times { number.prepend('0') }
      number
    end
  end
end
