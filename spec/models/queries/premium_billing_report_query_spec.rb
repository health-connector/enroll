# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Queries::PremiumBillingReportQuery, dbclean: :after_each do
  describe '#datatable_search' do
    let!(:person) { FactoryBot.create(:person, first_name: "Joe", last_name: "Kramer") }

    it 'builds a name search that treats regex metacharacters as literal text' do
      expect(Person).to receive(:any_of).with({ :first_name => /.*Kr\.mer.*/ }, { :last_name => /.*Kr\.mer.*/ }).and_call_original
      expect(described_class.new([]).datatable_search("Kr.mer").size).to eq 0
    end

    it 'does not raise on an unbalanced parenthesis in the search text' do
      expect { described_class.new([]).datatable_search("Kramer(").size }.not_to raise_error
    end
  end
end
