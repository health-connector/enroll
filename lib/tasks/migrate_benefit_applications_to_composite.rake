# frozen_string_literal: true

require 'csv'

namespace :migrations do
  desc "Migrate Benefit Applications to Composite"
  task :benefit_applications_to_composite => :environment do

    logger = Logger.new("#{Rails.root}/log/migrate_applications_to_composite-#{TimeKeeper.date_of_record.strftime('%Y_%m_%d')}.log")

    logger.info "Prerequisite: Fixing incorrect(non-payment) term reason for ER: (fein: 461585671, legal name: ONWRD hbx_id: 100456)"

    application = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(hbx_id: 100_456).first.benefit_applications.find('5b46ddf7aea91a4397e9a401')
    application.update_attribute(:termination_kind, 'nonpayment')

    logger.info "Generating a report of benefit_applications that has duplicate bson id"
    logger.info "Also Creating benefit_application_items for benefit_applications with duplicate bson id before-hand"
    logger.info "(since we can't use active record queries for it)"

    column_names = %w[
      LEGAL_NAME
      FEIN
      HBX_ID
      Duplication_Info
    ]

    CSV.open(file_name, "w", force_quotes: true) do |csv|
      csv << column_names

      BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.aggregate([
        { '$unwind' => "$benefit_applications" },
        { '$match' => { 'benefit_applications' => { '$exists' => true, '$ne' => [] }}},
        { '$group' => {
          '_id' => { 'application_id' => "$benefit_applications._id", 'created_at' => "$benefit_applications.created_at" },
          'count' => { '$sum' => 1 }
        }},

        { '$match' => {
          'count' => { '$gt' => 1 }
        }}
      ]).each do |row|
        application_id = row['_id']['application_id']
        benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(:"benefit_applications._id" => BSON.ObjectId(application_id))

        if benefit_sponsorships.size != 1
          logger.info "[Duplicate ID]: BenefitSponsorship mismatch: #{benefit_sponsorships.size}; application_id: #{application_id}; #{row}"
          next
        end

        benefit_sponsorship = benefit_sponsorships.first

        benefit_sponsorship_hash = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.find({ _id: benefit_sponsorship.id }).first

        benefit_sponsorship_hash[:benefit_applications].each do |app|
          item_hash = {
            created_at: DateTime.now,
            updated_at: DateTime.now,
            sequence_id: 0,
            effective_period: app[:effective_period],
            action_on: app[:terminated_on] || app[:updated_at] || app[:created_at],
            action_kind: app[:termination_kind],
            action_reason: app[:termination_reason],
            state: app[:aasm_state]
          }
          app['benefit_application_items'] = [item_hash]
        end

        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.collection.update_one({ _id: benefit_sponsorship.id }, benefit_sponsorship_hash)

        csv << [
          benefit_sponsorship.legal_name,
          benefit_sponsorship.fein,
          benefit_sponsorship.organization.hbx_id,
          row
        ]
      end
    end

    logger.info ":: processed benefit applications which has duplicate bson ids ::"

    logger.info ":: Starting Migrations ::"
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

    batch_size = 2500
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
          benefit_sponsorship.benefit_applications.where(:benefit_application_items => { :'$exists' => false }).each do |application|
            if no_action_application_states.include? application.aasm_state
              wfst = application.workflow_state_transitions.min_by(&:transition_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )
            end

            if [:terminated, :termination_pending].include? application.aasm_state

              effective_period = application.read_attribute(:effective_period)
              wfst = application.workflow_state_transitions.min_by(&:transition_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: effective_period['min']..(effective_period['min'] + 1.year - 1.day),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )

              application.benefit_application_items.create!(
                sequence_id: 1,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.read_attribute(:terminated_on),
                action_type: :change,
                action_kind: application.read_attribute(:termination_kind),
                action_reason: application.read_attribute(:termination_reason),
                state: application.aasm_state
              )

            end

            if [:canceled].include? application.aasm_state
              wfst = application.workflow_state_transitions.min_by(&:transition_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )

              cancled_wfst = application.workflow_state_transitions.where(to_state: 'canceled').first
              application.benefit_application_items.create!(
                sequence_id: 1,
                effective_period: application.read_attribute(:effective_period),
                action_on: cancled_wfst&.created_at || application.updated_at,
                state: :canceled
              )
            end

            # To handle legacy states; we're just storing it's current state
            unless all_application_states.include? application.aasm_state
              wfst = application.workflow_state_transitions.min_by(&:transition_at)
              application.benefit_application_items.create!(
                sequence_id: 0,
                effective_period: application.read_attribute(:effective_period),
                action_on: application.created_at,
                state: wfst&.from_state || application.aasm_state
              )
            end

            csv << [
              benefit_sponsorship.legal_name,
              benefit_sponsorship.fein,
              benefit_sponsorship.organization.hbx_id,
              application.aasm_state,
              application.read_attribute(:effective_period)['min'],
              application.read_attribute(:effective_period)['max'],
              application.read_attribute(:terminated_on),
              application.is_renewing?
            ]
          rescue StandardError => e
            logger.info "ACTION NEEDED(rescued) -- #{benefit_sponsorship.hbx_id} :: #{application.id} :: #{e} :: #{application.aasm_state}"
          end
          if benefit_sponsorship.reload.benefit_applications.where(:benefit_application_items => { :'$exists' => false }).present?
            logger.info ":: ALERT :: any application rescued(?) if not(why?) -- #{benefit_sponsorship.hbx_id} :: #{benefit_sponsorship.fein}"
          end
        end
      end

      offset += batch_size
    end
    end_time = DateTime.current
    logger.info ":: processing ended at #{end_time} ::"
    logger.info ":: processing took #{((end_time - start_time) * 24 * 60).to_f.ceil} minutes ::"

    benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
      :benefit_applications => { :'$exists' => true },
      :'benefit_applications.benefit_application_items' => { :'$exists' => false }
    )

    logger.info ":: ALERT :: #{benefit_sponsorships.size} benefit sponsorships exists without benefit application items."
  end
end
