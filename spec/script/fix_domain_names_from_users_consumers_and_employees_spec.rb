require 'rails_helper'
require File.join(Rails.root, "script", "fix_domain_names_from_users_consumers_and_employees")

describe FixDomainNames do
  before do
    5.times do
      person = FactoryGirl.create(:consumer_role_person)
      FactoryGirl.create(:consumer_role, person: person, bookmark_url: "fake_test.com/fake")
      FactoryGirl.create(:employee_role, person: person, bookmark_url: "fake_test.com/fake")
      FactoryGirl.create(:user, last_portal_visited: "fake_test.com/fake")
    end
  end

  subject { FixDomainNames.new(Person.all.to_a, User.all.to_a) }

  it "updates all person and user record susccessfully" do
  	subject.run
  	expect(User.first.last_portal_visited).to eq("")
  	expect(Person.last.consumer_role.bookmark_url).to eq("")
    expect(Person.last.employee_roles.last.bookmark_url).to eq("")
  end
end
