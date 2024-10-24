# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "remove_incorrect_person_relationship")

describe RemoveIncorrectPersonRelationship, dbclean: :after_each do

  let(:given_task_name) { "remove_incorrect_person_relationship" }
  subject { RemoveIncorrectPersonRelationship.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "destroying person relationships" do

    let(:person) { FactoryBot.create(:person)}

    before(:each) do
      person.person_relationships << PersonRelationship.new(kind: "child", relative_id: person.id)
      person.save!
    end

    it "should destroy the person relationship" do
      ClimateControl.modify hbx_id: person.hbx_id, _id: person.person_relationships.first.id do
        subject.migrate
        person.reload
        expect(person.person_relationships.size).to eq 0
      end
    end
  end
end
