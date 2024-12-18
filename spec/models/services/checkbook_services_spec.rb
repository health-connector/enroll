# frozen_string_literal: true

require 'rails_helper'

class ApplicationHelperModStubber
  extend ApplicationHelper
end

describe ::Services::CheckbookServices::PlanComparision, dbclean: :after_each do

  let(:census_employee) { FactoryBot.build(:census_employee, first_name: person.first_name, last_name: person.last_name, dob: person.dob, ssn: person.ssn, employee_role_id: employee_role.id)}
  let(:household) { FactoryBot.create(:household, family: person.primary_family)}
  let(:employee_role) { FactoryBot.create(:employee_role, person: person)}
  let(:person) { FactoryBot.create(:person, :with_family)}
  let!(:hbx_enrollment) { FactoryBot.create(:hbx_enrollment, household: census_employee.employee_role.person.primary_family.households.first, employee_role_id: employee_role.id)}

  describe "when employee is not congress" do
    subject { ::Services::CheckbookServices::PlanComparision.new(hbx_enrollment,false) }
    let(:result) {double("HttpResponse",:parsed_response => {"URL" => "http://checkbook_url"})}

    it "should generate non-congressional link" do
      if ApplicationHelperModStubber.plan_match_dc
        allow(subject).to receive(:construct_body).and_return({})
        allow(HTTParty).to receive(:post).with("https://staging.checkbookhealth.org/shop/dc/api/",
                                               {:body => "{}", :headers => {"Content-Type" => "application/json"}})
                                         .and_return(result)
        expect(subject.generate_url).to eq Settings.checkbook_services.congress_url
      end
    end
  end

  describe "when employee is congress member" do
    subject { ::Services::CheckbookServices::PlanComparision.new(hbx_enrollment,true) }

    it "should generate congressional url" do
      if ApplicationHelperModStubber.plan_match_dc
        allow(subject).to receive(:construct_body).and_return({})
        expect(subject.generate_url).to eq("https://dc.checkbookhealth.org/congress/dc/2018/")
      end
    end
  end
end
