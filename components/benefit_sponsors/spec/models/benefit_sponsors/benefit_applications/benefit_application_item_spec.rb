# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BenefitSponsors::BenefitApplications::BenefitApplicationItem, type: :model, :dbclean => :after_each do
  describe "new model instance" do
    it { is_expected.to be_mongoid_document }
    it { is_expected.to have_field(:effective_period).of_type(Range)}
    it { is_expected.to have_field(:item_type).of_type(Symbol)}
    it { is_expected.to have_field(:item_type_reason).of_type(String)}
    it { is_expected.to have_field(:sequence_id).of_type(Integer).with_default_value_of(0)}
    it { is_expected.to have_field(:state).of_type(Symbol)}
    it { is_expected.to have_field(:updated_by).of_type(String)}
  end
end
