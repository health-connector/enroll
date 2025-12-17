# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Validations::UsDate do
  context 'with allow_blank: false' do
    before do
      stub_const('UsDateTestModel', Class.new do
        include ActiveModel::Model
        include ActiveModel::Validations

        attr_accessor :start_date

        include Validations::UsDate.on(:start_date)
      end)
    end

    it 'is valid with a correct US date' do
      model = UsDateTestModel.new(start_date: '12/31/2024')
      expect(model).to be_valid
    end

    it 'is invalid with an incorrect date format' do
      model = UsDateTestModel.new(start_date: '31/12/2024')
      expect(model).not_to be_valid
    end

    it 'is invalid when blank' do
      model = UsDateTestModel.new(start_date: nil)
      expect(model).not_to be_valid
    end
  end

  context 'with allow_blank: true' do
    before do
      stub_const('UsDateTestModel', Class.new do
        include ActiveModel::Model
        include ActiveModel::Validations

        attr_accessor :start_date

        include Validations::UsDate.on(:start_date, allow_blank: true)
      end)
    end

    it 'is invalid when blank (existing behavior)' do
      model = UsDateTestModel.new(start_date: nil)
      expect(model).not_to be_valid
    end

    it 'is invalid when date format is incorrect' do
      model = UsDateTestModel.new(start_date: '2024-12-31')
      expect(model).not_to be_valid
    end
  end
end