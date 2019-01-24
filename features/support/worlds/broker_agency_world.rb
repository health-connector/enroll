module BrokerAgencyWorld
  def broker_organization
    @broker_organization ||= FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_broker_agency_profile, legal_name: 'First Legal Name', site: site)
  end

  def broker_agency_profile
    @broker_agency_profile = broker_organization.broker_agency_profile
  end

  def broker_agency_account
    @broker_agency_account ||= FactoryGirl.build(:benefit_sponsors_accounts_broker_agency_account, broker_agency_profile: broker_agency_profile)
  end

  def assign_person_to_broker_agency
    broker_agency_profile.update_attributes!(primary_broker_role_id: broker.person.broker_role.id)
    broker_agency_profile.approve!
  end

  def assign_broker_agency_account
    employer_profile.benefit_sponsorships << broker_agency_account
    employer_profile.organization.save!
  end

  def broker(*traits)
    attributes = traits.extract_options!
    @broker_organization ||= FactoryGirl.create(
      :benefit_sponsors_organizations_general_organization,
      :with_broker_agency_profile,
      attributes.merge(site: site)
    )
  end

  def carrier(name)
    @carriers ||= {}
    @carrier[name] ||= FactoryGirl.create(:carrier_profile).tap do |carrier|
      FactoryGirl.create(:carrier_service_area, issuer_hios_id: carrier.issuer_hios_ids.first, serves_entire_state: true, service_area_id: 'EX123')
    end
  end

  def proposal_plan(*traits)
    @proposal_plan ||= FactoryGirl.create :plan, carrier: carrier(:default)
  end

  def prospect_employer(*traits) # this is for BQT propsects because they use old models
    attributes = traits.extract_options!
    @prospect_employer ||= FactoryGirl.create(
      :sponsored_benefits_plan_design_organization,
      *traits,
      attributes.merge(sponsor_profile_id: nil)
    ).tap do |prospect_employer|
      prospect_employer.plan_design_proposals.first.profile.benefit_sponsorships.first.update_attributes initial_enrollment_period: Date.today.at_beginning_of_month.next_month.next_month..Date.today.at_end_of_month.next_month.next_month
    end
  end

  def broker_quote
    prospect_employer.plan_design_proposals.first
  end
end

World(BrokerAgencyWorld)

Given(/^there is a Broker (.*?)$/) do |legal_name|
  broker legal_name: legal_name,
         dba: legal_name
  #benefit_sponsorship(broker)
end

And(/^the broker is assigned to a broker agency$/) do
  assign_person_to_broker_agency
end
