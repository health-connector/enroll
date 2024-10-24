# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transcripts::FamilyTranscript, type: :model do

  describe "find_or_build_family" do

    let!(:spouse)  { FactoryBot.create(:person)}
    let!(:child1)  { FactoryBot.create(:person)}
    let!(:child2)  { FactoryBot.create(:person)}

    let!(:person) do
      p = FactoryBot.build(:person)
      p.person_relationships.build(relative: spouse, kind: "spouse")
      p.person_relationships.build(relative: child1, kind: "child")
      p.person_relationships.build(relative: child2, kind: "child")
      p.save
      p
    end

    context "Family already exists" do

      let(:other_family) do
        family = Family.new({
                              hbx_assigned_id: '24112',
                              e_case_id: "6754632"
                            })
        family.family_members.build(is_primary_applicant: true, person: person)
        family.family_members.build(is_primary_applicant: false, person: child1)
        family.irs_groups.build(hbx_assigned_id: '651297232112', effective_starting_on: Date.new(2016,1,1), effective_ending_on: Date.new(2016,12,31), is_active: true)
        family
      end

      let!(:source_family) do
        family = Family.new({ hbx_assigned_id: '25112', e_case_id: "6754632" })
        family.family_members.build(is_primary_applicant: true, person: person)
        family.family_members.build(is_primary_applicant: false, person: spouse)
        family.save
        family
      end

      def build_transcript
        factory = Transcripts::FamilyTranscript.new
        factory.find_or_build(other_family)
        factory.transcript
      end

      context "and dependent family member missing" do

        it 'should have add on dependnet' do
          build_transcript
        end
      end
    end
  end
end
