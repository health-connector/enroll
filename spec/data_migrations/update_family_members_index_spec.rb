require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "update_family_members_index")

describe UpdateFamilyMembersIndex do

  let(:given_task_name) { "update_family_members_index" }
  subject { UpdateFamilyMembersIndex.new(given_task_name, double(:current_scope => nil)) }
  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end
  describe "case with if both primary_person and dependent is not present" do
    context "case with if dependent not present" do
      it "found no family with given dependent_hbx" do
        options = {action_task: 'update_family_member_index', primary_hbx: '1111', dependent_hbx: ''}
        expect {fm_index_migrate(options)}.to raise_error('some error person with hbx_id:1111 and hbx_id: not found')
      end
    end

    context "case with if primary_person not present" do
      it "found no family with given primary_hbx" do
        expect {fm_index_migrate(action_task: 'update_family_member_index', primary_hbx: '', dependent_hbx: '1112')}.to raise_error('some error person with hbx_id: and hbx_id:1112 not found')
      end
    end
  end

  describe "update family_members index", dbclean: :after_each do

    let(:wife) { FactoryBot.create(:person, first_name: "wifey")}
    let(:husband) { FactoryBot.create(:person, first_name: "hubby")}
    let(:family) { FactoryBot.build(:family) }
    let!(:husbands_family) do
      husband.person_relationships << PersonRelationship.new(relative_id: husband.id, kind: "self")
      husband.person_relationships << PersonRelationship.new(relative_id: wife.id, kind: "spouse")
      husband.save

      family.add_family_member(wife)
      family.add_family_member(husband, is_primary_applicant: true)
      family.save
      family
    end

    it "should swap the index of family members" do
      options = {action_task: 'update_family_member_index', primary_hbx: husband.hbx_id, dependent_hbx: wife.hbx_id, primary_family_id: family_member1.id, dependent_family_id: family_member2.id}
      fm_index_migrate(options)
      husbands_family.reload
      hus_fam_id = husbands_family.family_members.first.id
      wife_fam_id = husbands_family.family_members.second.id
      expect(husbands_family.family_members.where(id: hus_fam_id).first.is_primary_applicant?).to eq true
      expect(husbands_family.family_members.where(id: wife_fam_id).first.is_primary_applicant?).to eq false

      expect(family_member2.reload.person_id).to eq wife.id
    end
  end
end

def fm_index_migrate(options)
  ClimateControl.modify options do
    subject.migrate
  end
end
