class GenerateDcSite < Mongoid::Migration
  def self.up
    if Settings.site.key.to_s == "dc"
      say_with_time("Creating DC Site") do
        @site = ::BenefitSponsors::Site.new(
          site_key: :dc,
          byline: "The Right Place for the Right Plan",
          short_name: "DC Health Benefit Exchange",
          domain_name: "www.dchealthlink.com",
          long_name: "DC's Online Health Insurance Marketplace")

        @old_org = Organization.unscoped.exists(hbx_profile: true).first
        @old_profile = @old_org.hbx_profile

        new_profile = initialize_hbx_profile
        owner_organization = initialize_exempt_organization(new_profile)
        owner_organization.save!
        update_hbx_staff_roles(new_profile) # updates person hbx_staff_role with new profile id
        @site.owner_organization = owner_organization
      end

      say_with_time("Creating DC ACA IVL Benefit Market") do
        inital_app_config = BenefitMarkets::Configurations::AcaIndividualInitialApplicationConfiguration.new
        configuration = BenefitMarkets::Configurations::AcaIndividualConfiguration.new(initial_application_configuration: inital_app_config)
        @benefit_market = BenefitMarkets::BenefitMarket.new kind: :aca_individual,
          site_urn: 'dc',
          title: 'ACA IVL',
          description: 'DC ACA IVL Market',
          configuration: configuration
      end

      @site.benefit_markets << @benefit_market

      if @site.valid?
        @site.save!
      else
        puts @site.configuration.errors.full_messages.inspect
      end

      if @benefit_market.valid?
        @benefit_market.site = @site
        @benefit_market.save!
      else
        puts @benefit_market.configuration.errors.full_messages.inspect
      end
      hbx_profile = @site.owner_organization.profiles.first

      say_with_time("Creating DC BenefitSponsorship") do
        hbx_profile.update_attribute(:is_benefit_sponsorship_eligible, true)
        hbx_profile.add_benefit_sponsorship
        @site.owner_organization.active_benefit_sponsorship.save!
        @site.owner_organization.save!
      end
    end
  end

  def self.down
    # raise "Migration is not reversable."
  end

  def self.sanitize_hbx_params
    json_data = @old_profile.to_json(:except => [:_id, :hbx_staff_roles, :updated_by_id, :enrollment_periods, :benefit_sponsorship, :inbox, :documents])
    JSON.parse(json_data)
  end

  def self.initialize_hbx_profile
    profile = ::BenefitSponsors::Organizations::HbxProfile.new(self.sanitize_hbx_params)
    build_inbox_messages(profile)
    build_documents(profile)
    build_office_locations(profile)
    profile
  end

  def self.build_inbox_messages(new_profile)
    @old_profile.inbox.messages.each do |message|
      new_profile.inbox.messages.new(message.attributes.except("_id"))
    end
  end

  def self.build_documents(new_profile)
    @old_org.documents.each do |document|
      new_profile.documents.new(document.attributes.except("_id"))
    end
  end

  def self.build_benefit_application(benefit_sponsorship)
    benefit_application = benefit_sponsorship.benefit_applications.build
  end

  def self.build_office_locations(new_profile)
    @old_org.office_locations.each do |office_location|
      new_office_location = new_profile.office_locations.new()
      new_office_location.is_primary = office_location.is_primary
      address_params = office_location.address.attributes.except("_id")
      phone_params = office_location.phone.attributes.except("_id")
      new_office_location.address = address_params
      new_office_location.phone = phone_params
    end
  end

  def self.initialize_exempt_organization(new_profile)
    json_data = @old_org.to_json(:except => [:_id, :updated_by_id, :hbx_profile, :issuer_assigned_id,:office_locations, :version, :updated_by, :is_fake_fein, :is_active])
    exempt_organization = BenefitSponsors::Organizations::ExemptOrganization.new(JSON.parse(json_data))
    exempt_organization.site = @site
    exempt_organization.profiles << [new_profile]
    exempt_organization
  end

  def self.update_hbx_staff_roles(new_profile)
    Person.where(:'hbx_staff_role'.exists=>true).each do |person|
      person.hbx_staff_role.benefit_sponsor_hbx_profile_id = new_profile.id
      person.save!
    end
  end
end