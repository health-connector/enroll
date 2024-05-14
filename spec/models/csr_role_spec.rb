# frozen_string_literal: true

require 'rails_helper'
require 'aasm/rspec'

describe CsrRole, type: :model, dbclean: :after_each do

  let!(:person1) { FactoryGirl.create(:person, :with_csr_role, first_name: 'Jaxon', last_name: 'Perry') }
  let!(:person2) { FactoryGirl.create(:person, :with_csr_role, first_name: 'Quinn', last_name: 'Perry') }

  describe "find_by_name" do
    let(:first_name) { 'Quinn' }
    let(:last_name) { 'Perry' }
    let(:cac_flag) { false }

    let(:params) do
      {
        first_name: first_name,
        last_name: last_name,
        cac_flag: cac_flag
      }
    end

    context "with string inputs" do
      it "should find matched person with csr role" do
        result = CsrRole.find_by_name(first_name, last_name, cac_flag)

        expect(result.count).to eq 1
        expect(result.first).to eq person2
      end
    end

    context "with regex fragment for names" do
      let(:first_name) { "\\w+" }
      let(:last_name) { "\\w+" }

      it "should santize input names using regex" do
        result = CsrRole.find_by_name(first_name, last_name, cac_flag)

        expect(result).to be_blank
        expect(result.selector['$and'][0]['first_name']).to eq(/^#{Regexp.escape(first_name)}$/i)
        expect(result.selector['$and'][1]['last_name']).to eq(/^#{Regexp.escape(last_name)}$/i)
      end
    end
  end
end
