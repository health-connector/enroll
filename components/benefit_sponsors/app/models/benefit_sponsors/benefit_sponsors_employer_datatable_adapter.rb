module BenefitSponsors
  class BenefitSponsorsEmployerDatatableAdapter
    include Enumerable
    attr_accessor :pipeline

    def initialize(criterias)
      @criterias = criterias
    end

    def each
      @criterias.each do |criteria|
        # Figure out uwhat to put here
      end
    end

    def size
      return 0 if @criterias.empty?
      @count ||= begin
                   @criterias.inject(0) do |acc, criteria|
                     acc + criteria.last.count
                   end
                 end
    end

    def datatable_search(str)
      @employer_datatable = @criterias.first[0]
      @pipeline = @criterias.first[1].pipeline
      search_collection(str)
      self
    end

  #def search_collection(str)
  #  employee_role_ids = Person.where(
  #    :"employee_roles.benefit_sponsors_employer_profile_id" => sponsored_benefit.benefit_sponsorship.profile_id,
  #    :"$or" => [
  #      {first_name: /#{str}/i}, {last_name: /#{str}/i}
  #    ]
  #  ).map(&:employee_roles).flatten.map(&:id)

  #  add({"$project" => {"hbx_enrollments": 1}})
  #  add({"$match" => {
  #      "hbx_enrollments.employee_role_id" => {"$in" => employee_role_ids}
  #  }})
  #    add({"$group" => {
  #      "_id" => {
  #        "bga_id" => "$hbx_enrollments.sponsored_benefit_id",
  #        "employee_role_id" => "$hbx_enrollments.employee_role_id"
  #      },
  #      "hbx_enrollment_id" => {"$last" => "$hbx_enrollments._id"}
  #    }})
  #  end
    
    # TODO: This is what I was doing in the datatable before, is this what we're suppose dto do?
    def search_collection(str)
      if str.blank?
        # TODO: Do we need benefit sponsorships unscoped?
        benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.unscoped
      else
        # benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.aggregate([table_query])
        # sponsorship_ids = benefit_sponsorships.map { |id| id["_id"].to_s }
        # @employer_collection = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:_id.in => sponsorship_ids)
        # Default query for all unscoped
        table_query = {"$group" => {"_id" => "$_id"}}
        # States
        enrolling_states = [:draft, :enrollment_open, :enrollment_extended, :enrollment_closed, :enrollment_eligible, :binder_paid]
        # Queries
        enrolling_query = {
          "$match" => {
            :"benefit_applications.aasm_state".in => enrolling_states,
            :"benefit_applications.predecessor_id" => {:$exists => false}
          }
        }
        enrolling_renewing_query = {
          "$match" => {
            :"benefit_applications.aasm_state".in => [:draft, :enrollment_open, :enrollment_extended, :enrollment_closed, :enrollment_eligible],
            :"benefit_applications.predecessor_id" => {:$exists => true}
          }
        }
        employers_query = {"$match" => {:"benefit_applications.aasm_state".in => [:enrollment_closed, :enrollment_eligible, :active]}}
        enrolled_query = {"$match" => {:"benefit_applications.aasm_state".in => [:enrollment_closed, :enrollment_eligible, :active]}}
        employer_attestation_orgs = BenefitSponsors::Organizations::Organization.employer_profiles.where(
          :"profiles.employer_attestation.aasm_state".in => employer_attestation_kinds
        )
        employer_attestations_query = {
          "$match" => {:organization.in => employer_attestation_orgs.collect{|org| org.id.to_s}}
        }
        if attributes[:employers].present? && !['all'].include?(attributes[:employers])
          table_query.merge!(employers_query) if employer_kinds.include?(attributes[:employers])
          if attributes[:enrolling].present?
            if attributes[:enrolling_initial].present? || attributes[:enrolling_renewing].present?
              table_query.merge!(enrolling_query) if attributes[:enrolling_initial].present? && attributes[:enrolling_initial] != 'all'
              table_query.merge!(enrolling_renewing_query) if attributes[:enrolling_renewing].present? && attributes[:enrolling_renewing] != 'all'
              table_query.merge!(enrolling_query) if attributes[:enrolling_initial].present? && attributes[:enrolling_initial] == 'all' || attributes[:enrolling_renewing].present? && attributes[:enrolling_renewing] == 'all'
            else
              table_query.merge!(enrolling_query)
            end
          end

          table_query.merge!(enrolled_query) if attributes[:employers] == 'benefit_application_enrolled'
          table_query.merge!(employer_attestations_query) if attributes[:employers] == 'employer_attestations'

          if attributes[:upcoming_dates].present?
            if date = Date.strptime(attributes[:upcoming_dates], "%m/%d/%Y").present?
              date = Date.strptime(attributes[:upcoming_dates], "%m/%d/%Y")
              upcoming_dates_query = {
                "$match" => {:"benefit_applications.effective_period.min" => date}
              }
              table_query.merge!(upcoming_dates_query)
            end
          end

          if attributes[:employers] == 'employer_attestations'
            attestations_by_kinds_orgs = BenefitSponsors::Organizations::Organization.employer_profiles.where(:"profiles.employer_attestation.aasm_state".in => employer_attestation_kinds)
            # self.where(:"organization".in => orgs.collect{|org| org.id})}
            employer_attestation_by_kind_query = {
              "$match" => {:"organization".in => attestations_by_kinds_orgs.map{|org| org.id.to_s}}
            }
            table_query.merge!(employer_attestation_by_kind_query)
          end
        end
        benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.aggregate([table_query])
        sponsorship_ids = benefit_sponsorships.map { |id| id["_id"].to_s }
        @employer_collection = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:_id.in => sponsorship_ids)
      end
    end

    def add(step)
      pipeline << step.to_hash
    end

    def order_by(opts = {})
      self
    end

    def skip(num)
      self
    end

    def limit(num)
      self
    end
  end
end
