# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::BenefitApplications::BenefitApplicationItem, type: :model, :dbclean => :after_each do
  describe "new model instance" do
    before do
      allow(TimeKeeper).to receive(:date_of_record).and_call_original
    end

    it { is_expected.to be_mongoid_document }
    it { is_expected.to have_field(:effective_period).of_type(Range)}
    it { is_expected.to have_field(:action_type).of_type(Symbol)}
    it { is_expected.to have_field(:action_kind).of_type(String)}
    it { is_expected.to have_field(:action_on).of_type(Date).with_default_value_of(TimeKeeper.date_of_record)}
    it { is_expected.to have_field(:action_reason).of_type(String)}
    it { is_expected.to have_field(:sequence_id).of_type(Integer)}
    it { is_expected.to have_field(:state).of_type(Symbol)}
    it { is_expected.to have_field(:updated_by).of_type(String)}
  end
end
