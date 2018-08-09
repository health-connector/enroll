BenefitSponsors::BenefitSponsorships::BenefitSponsorship.all.each do |benefit_sponsorship|
  if (benefit_sponsorship.renewal_benefit_application.present? || benefit_sponsorship.active_benefit_application.present?) && benefit_sponsorship.aasm_state != :active
    benefit_sponsorship.workflow_state_transitions << WorkflowStateTransition.new(from_state: benefit_sponsorship.aasm_state, to_state: :active)
    benefit_sponsorship.update_attributes(aasm_state: :active)
  end
end