# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "delink_user_and_person")

describe DelinkUserAndPerson do

  let(:given_task_name) { "delink_user_and_person" }
  let!(:person) { FactoryBot.create(:person)}
  let!(:user) {FactoryBot.create(:user,person: person)}

  subject { DelinkUserAndPerson.new(given_task_name, double(:current_scope => nil)) }

  it "should delink the person from user" do
    ClimateControl.modify person_hbx_id: person.hbx_id do
      expect(person.user).not_to eq nil
      subject.migrate
      person.reload
      expect(person.user).to eq nil
    end
  end

  it "after delink the user should exists" do
    ClimateControl.modify person_hbx_id: person.hbx_id do
      id = user.id
      expect(User.where(id: id)).not_to eq nil
      subject.migrate
      user.reload
      expect(User.where(id: id)).not_to eq nil
    end
  end
end
