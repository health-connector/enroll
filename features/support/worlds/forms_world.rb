module FormsWorld

    def generate_sic_codes
    cz_pattern = Rails.root.join("db", "seedfiles", "fixtures", "sic_codes", "sic_code_*.yaml")

    Mongoid::Migration.say_with_time("Load SIC Codes") do
      Dir.glob(cz_pattern).each do |f_name|
        loaded_class_1 = ::SicCode
        yaml_str = File.read(f_name)
        data = YAML.load(yaml_str)
        data.new_record = true
        data.save!
      end
    end
  end

  def fill_in_prospect_employer_form
    fill_in 'organization_legal_name', with: prospect_employer.legal_name
    fill_in 'organization_dba', with: prospect_employer.dba
    select 'Tax Exempt Organization', from: 'organization_entity_kind'
    Capybara.ignore_hidden_elements = false
    select(
      '0111',
      from: 'organization[sic_code]'
    )
    # select "0111", from: "organization_sic_code_chosen"
    fill_in 'organization_office_locations_attributes_0_address_attributes_address_1', with: prospect_employer.employer_profile.office_locations.first.address.address_1
    select prospect_employer.employer_profile.office_locations.first.address.state, from: 'organization_office_locations_attributes_0_address_attributes_state'
    fill_in 'organization_office_locations_attributes_0_address_attributes_zip', with: prospect_employer.employer_profile.office_locations.first.address.zip
    fill_in 'organization_office_locations_attributes_0_phone_attributes_area_code', with: prospect_employer.employer_profile.office_locations.first.phone.area_code
    fill_in 'organization_office_locations_attributes_0_phone_attributes_number', with: prospect_employer.employer_profile.office_locations.first.phone.number
  end

  def fill_in_quotes_form(quote_name)
    fill_in("forms_plan_design_proposal[title]", with: quote_name)
    date_select = find(:xpath, "//*[@id='new_forms_plan_design_proposal']/div[1]/div/div[1]/div[2]/div/div[2]/div/div[2]/p")
    date_select.click
    date_select_options = page.all(".interaction-choice-control-forms-plan-design-proposal-effective-date-1")
    # This is the right one for the March 2019 (or whatever the date will be)
    date_select_options[1].trigger('click')
  end
end

World(FormsWorld)

And(/^all required fields have valid inputs on the Prospect Employer Form$/) do
  fill_in_prospect_employer_form
end