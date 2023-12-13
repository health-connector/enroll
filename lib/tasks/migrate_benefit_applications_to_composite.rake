require 'csv'

namespace :migrations do
  desc "Migrate Benefit Applications to Composite"
  task :benefit_applications_to_composite => :environment do

    logger = Logger.new("#{Rails.root}/log/migrate_applications_to_composite-#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.log")
    field_names = %w[
      LEGAL_NAME
      FEIN
      HBX_ID
      AASM_STATE
      START_ON
      END_ON
      TERMINATED_ON
      IS_RENEWING
    ]

    no_action_application_states = [
      :pending, :assigned, :processing, :reviewing, :information_needed, :appealing,
      :draft, :imported, :approved, :denied, :enrollment_open, :enrollment_extended,
      :enrollment_closed, :enrollment_eligible, :binder_paid, :enrollment_ineligible,
      :active, :suspended, :expired
    ]

    all_application_states = no_action_application_states + [:terminated, :termination_pending, :canceled]

    benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
      :benefit_applications => { :'$exists' => true },
      :'benefit_applications.benefit_application_items' => { :'$exists' => false }
    )

    batch_size = 1000
    offset = 0
    count =  benefit_sponsorships.size
    start_time = DateTime.current
    logger.info ":: processing started at #{start_time} ::"
    logger.info ":: processing a total of #{count} records ::"

    while offset <= count
      logger.info ":: processing #{offset}-#{offset + batch_size} records ::"
      file_name = "#{Rails.root}/migrate_application_composite_results-#{offset}-#{offset + batch_size}.csv"
      CSV.open(file_name, "w", force_quotes: true) do |csv|
        csv << field_names

        benefit_sponsorships.offset(offset).limit(batch_size).no_timeout.each do |benefit_sponsorship|
          benefit_sponsorship.benefit_applications.each do |application|
            if no_action_application_states.include? application.aasm_state
              if application.read_attribute(:terminated_on).present?
                logger.info "ACTION NEEDED(has term date): -- #{benefit_sponsorship.hbx_id} :: #{application.id} :: #{application.aasm_state}"
                next
              else
                wfst = application.workflow_state_transitions.min_by(&:created_at)
                application.benefit_application_items.create!(
                  sequence_id: 0,
                  effective_period: application.read_attribute(:effective_period),
                  action_on: application.created_at,
                  state: wfst&.from_state || application.aasm_state
                )
                logger.info "Created Item for -- #{benefit_sponsorship.hbx_id} :: #{application.id}"
              end
            end

            if [:terminated, :termination_pending].include? application.aasm_state

              effective_period = application.read_attribute(:effective_period)
              wfst = application.workflow_state_transitions.min_by(&:created_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: effective_period.min..(effective_period.min + 1.year - 1.day),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )

              logger.info "Created Item for -- #{benefit_sponsorship.hbx_id} :: #{application.id}"

              application.benefit_application_items.create!(
                sequence_id: 1,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.read_attribute(:terminated_on),
                action_type: :change,
                action_kind: application.read_attribute(:termination_kind),
                action_reason: application.read_attribute(:termination_reason),
                state: application.aasm_state
              )

              logger.info "Created Item for -- #{benefit_sponsorship.hbx_id} :: #{application.id}"
            end

            if [:canceled].include? application.aasm_state
              wfst = application.workflow_state_transitions.min_by(&:created_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )
              logger.info "Created Item for -- #{benefit_sponsorship.hbx_id} :: #{application.id}"

              cancled_wfst = application.workflow_state_transitions.where(to_state: 'canceled').first
              application.benefit_application_items.create!(
                sequence_id: 1,
                effective_period: application.read_attribute(:effective_period),
                action_on: cancled_wfst&.created_at || application.updated_at,
                state: :canceled
              )
              logger.info "Created Item for -- #{benefit_sponsorship.hbx_id} :: #{application.id}"
            end

            unless all_application_states.include? application.aasm_state
              logger.info "ACTION NEEDED(state ambiguity): -- #{benefit_sponsorship.hbx_id} :: #{application.id} :: #{application.aasm_state}"
              next
            end

            csv << [
              benefit_sponsorship.legal_name,
              benefit_sponsorship.fein,
              benefit_sponsorship.hbx_id,
              application.aasm_state,
              application.read_attribute(:effective_period).min,
              application.read_attribute(:effective_period).max,
              application.read_attribute(:terminated_on),
              application.is_renewing?
            ]
          rescue StandardError => e
            logger.info "ACTION NEEDED(rescued) -- #{benefit_sponsorship.hbx_id} :: #{application.id} :: #{e} :: #{application.aasm_state}"
          end
        end
      end

      offset += batch_size
    end
    end_time = DateTime.current
    logger.info ":: processing ended at #{end_time} ::"
    logger.info ":: processing took #{((end_time - start_time) * 24 * 60).to_f.ceil} minutes ::"
  end
end
