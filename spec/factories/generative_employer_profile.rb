# frozen_string_literal: true

FactoryBot.define do

  factory(:generative_office_location, {class: OfficeLocation}) do
    is_primary { Forgery('basic').boolean }
    address do
      FactoryBot.build_stubbed :generative_address if Forgery('basic').boolean
    end
    phone do
      FactoryBot.build_stubbed :generative_phone
    end
  end

  factory(:generative_organization, {class: Organization}) do
    legal_name  { "#{Forgery('name').company_name} #{Forgery('name').industry}" }
    dba { "A string" }
    fein { Forgery(:basic).number({:min => 0, :max => 999_999_999}).to_s.rjust(9, '0') }
    home_page { "http://#{Forgery(:internet).domain_name}" }
    updated_at { DateTime.new }
    created_at { DateTime.new }
    is_active { Forgery('basic').boolean }
    office_locations do
      example_count = Random.rand(4)
      (0..example_count).to_a.map do |_e|
        FactoryBot.build_stubbed :generative_office_location
      end
    end
  end

  factory(:generative_carrier_profile, {class: CarrierProfile}) do
    organization do
      FactoryBot.build_stubbed :generative_organization
    end
  end

  factory(:generative_reference_plan, {class: Plan}) do
    active_year { 2015 }
    hios_id { "JDFLKJELKFJKLDJFIODFIE-01" }
    coverage_kind do
      pick_list = Plan::COVERAGE_KINDS
      max = pick_list.length
      pick_list[Random.rand(max)]
    end
    metal_level do
      pick_list = Plan::METAL_LEVEL_KINDS
      max = pick_list.length
      pick_list[Random.rand(max)]
    end
    carrier_profile do
      FactoryBot.build_stubbed :generative_carrier_profile
    end
  end

  factory(:generative_relationship_benefit, {class: RelationshipBenefit}) do
    transient do
      rel_kind { "" }
    end
    relationship { rel_kind }
    premium_pct { Random.rand * 100.00 }
    offered { Forgery('basic').boolean }
  end

  factory(:generative_benefit_group, {class: BenefitGroup}) do
    reference_plan { FactoryBot.build_stubbed :generative_reference_plan }
    relationship_benefits do
      (BenefitGroup::PERSONAL_RELATIONSHIP_KINDS.map do |rk|
        FactoryBot.build_stubbed(:generative_relationship_benefit, :rel_kind => rk)
      end)
    end
  end

  factory(:generative_plan_year, {class: PlanYear}) do
    open_enrollment_start_on { Date.today }
    open_enrollment_end_on { Date.today }
    start_on { Date.today }
    end_on { Date.today }
    benefit_groups do
      example_count = Random.rand(4)
      (0..example_count).to_a.map do |_e|
        FactoryBot.build_stubbed :generative_benefit_group
      end
    end
  end

  factory(:generative_person, {class: Person}) do
    first_name { Forgery(:name).first_name }
    last_name { Forgery(:name).first_name }
    hbx_id { "76f55832508f4e5087c5d5d944664b9f" }
  end

  factory(:generative_owner, {class: Person}) do
    first_name { Forgery(:name).first_name }
    last_name { Forgery(:name).first_name }
  end

  factory(:generative_broker_agency_profile, {class: BrokerAgencyProfile }) do
    ach_routing_number { "123456789" }
    ach_account_number { "9999999999999999" }
    organization { FactoryBot.build_stubbed :generative_organization }
    corporate_npn { "11234234" }
  end

  factory(:generative_broker_role, {class: BrokerRole}) do
    person { FactoryBot.build_stubbed :generative_person}
  end

  factory(:generative_broker_agency_account, {class: BrokerAgencyAccount}) do
    start_on { DateTime.now }
    end_on { DateTime.now }
    broker_agency_profile do
      FactoryBot.build_stubbed :generative_broker_agency_profile
    end
    writing_agent { FactoryBot.build_stubbed :generative_broker_role }
  end

  factory(:generative_employer_profile, {class: EmployerProfile}) do
    entity_kind do
      pick_list = Organization::ENTITY_KINDS
      max = pick_list.length
      pick_list[Random.rand(max)]
    end
    organization { FactoryBot.build_stubbed :generative_organization }
    plan_years do
      example_count = Random.rand(6)
      (0..example_count).to_a.map do |_e|
        FactoryBot.build_stubbed :generative_plan_year
      end
    end
    broker_agency_accounts do
      example_count = Random.rand(2)
      (0..example_count).to_a.map do |_e|
        FactoryBot.build_stubbed :generative_broker_agency_account
      end
    end

    after(:stub) do |obj|
      extend RSpec::Mocks::ExampleMethods
      allow(obj).to receive(:staff_roles).and_return([(FactoryBot.build_stubbed :generative_person)])
    end
  end
end
