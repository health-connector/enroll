# frozen_string_literal: true

require 'rails_helper'

module BenefitMarkets
  RSpec.describe Products::PremiumValueProduct, type: :model, dbclean: :after_each do
    describe 'fields' do
      it { is_expected.to have_field(:hios_id).of_type(String) }
      it { is_expected.to have_field(:active_year).of_type(Integer) }
    end

    describe 'associations' do
      it { is_expected.to belong_to(:product) }
      it { is_expected.to have_field(:product_id).of_type(Object) }
      it { is_expected.to belong_to(:rating_area) }
      it { is_expected.to have_field(:rating_area_id).of_type(Object) }
    end
  end
end
