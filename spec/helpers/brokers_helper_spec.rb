# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrokersHelper, type: :helper, dbclean: :after_each do
  let(:lang_en) { double('lang_en', iso_639_1: 'en', name: 'English', common_name: nil) }
  let(:lang_es) { double('lang_es', iso_639_1: 'es', name: 'Spanish', common_name: nil) }
  let(:lang_el) { double('lang_el', iso_639_1: 'el', name: 'Modern Greek (1453-)', common_name: 'Greek') }

  before do
    # Stub the language list to make tests deterministic and isolated from the gem data
    stub_const('LanguageList::COMMON_LANGUAGES', [lang_en, lang_es, lang_el])
  end

  describe '#humanized_language_list' do
    it 'returns empty string for nil' do
      expect(helper.humanized_language_list(nil)).to eq ''
    end

    it 'returns empty string for empty arrays or only-blank entries' do
      expect(helper.humanized_language_list([])).to eq ''
      expect(helper.humanized_language_list(['', nil, ' '])).to eq ''
    end

    it 'filters blank entries and maps known codes to friendly names' do
      expect(helper.humanized_language_list(['', 'en'])).to eq 'English'
    end

    it 'strips whitespace and accepts symbol or string codes' do
      expect(helper.humanized_language_list([:en, ' es '])).to eq 'English and Spanish'
    end

    it 'prefers common_name when available' do
      expect(helper.humanized_language_list(['el'])).to eq 'Greek'
    end

    it 'falls back to uppercase code when unknown' do
      expect(helper.humanized_language_list(['xx'])).to eq 'XX'
    end
  end

  describe '#humanized_language_list_for' do
    it 'accepts an object that responds to broker_agency_profile' do
      profile = double('profile', languages_spoken: ['', 'en'])
      role = double('role', broker_agency_profile: profile)

      expect(helper.humanized_language_list_for(role)).to eq 'English'
    end

    it 'returns empty string when broker_agency_profile is nil' do
      role = double('role', broker_agency_profile: nil)

      expect(helper.humanized_language_list_for(role)).to eq ''
    end

    it 'accepts an array of codes directly' do
      expect(helper.humanized_language_list_for(['en', 'es'])).to eq 'English and Spanish'
    end
  end
end
