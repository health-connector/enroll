# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "broker_agencies/profiles/_families_table_for_broker.html.erb" do

  context "shows families", dbclean: :after_each do

    let(:family1) { FactoryBot.create(:family, :with_primary_family_member)}

    let(:families) { [family1]}

    it "should render the partial" do
      family1.primary_applicant.person.update_attributes!(ssn: 123_444_567)
      render partial: 'broker_agencies/profiles/families_table_for_broker', :collection => [families], as: :families
      expect(rendered).to match(/Primary Applicant/)
      expect(rendered).to have_selector(".consumer_role_present", text: 'No')
      expect(rendered).to have_selector(".employee_role_present", text: 'No')
      expect(rendered).to have_selector('tbody tr', count: 1)
      expect(rendered).to include('***-**-4567')
      expect(rendered).not_to have_selector('a', text: 'Unblock')
    end

    it 'should check consumer role' do
      family1.primary_applicant.person.consumer_role = FactoryBot.build(:consumer_role)
      render partial: 'broker_agencies/profiles/families_table_for_broker', :collection => [families], as: :families
      expect(rendered).to have_selector(".consumer_role_present", text: 'Yes')
    end

    it 'should check employee role' do
      family1.primary_applicant.person.employee_roles = [FactoryBot.build(:employee_role)]
      allow(family1.primary_applicant.person).to receive(:active_employee_roles).and_return(true)
      render partial: 'broker_agencies/profiles/families_table_for_broker', :collection => [families], as: :families
      expect(rendered).to have_selector(".employee_role_present", text: 'Yes')
    end

    it 'should not link to phone enrollment' do
      render partial: 'broker_agencies/profiles/families_table_for_broker', :collection => [families], as: :families
      expect(rendered).not_to have_selector("a", text: /phone/)
    end
  end
end
