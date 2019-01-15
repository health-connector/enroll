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

end

World(BrokerAgencyWorld)

Given(/^there is a Broker (.*?)$/) do |legal_name|
  broker legal_name: legal_name,
         dba: legal_name
  #benefit_sponsorship(broker)
end

And(/^the person is assigned to a broker agency$/) do
  assign_person_to_broker_agency
end
