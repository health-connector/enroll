# frozen_string_literal: true

module BrokersHelper
  # Convert an array of language codes into a human-readable sentence.
  # - filters out blank values
  # - maps ISO-639-1 codes to friendly names from LanguageList
  # - falls back to the uppercase code when unknown
  # Examples:
  #   humanized_language_list(["en","es"]) => "English and Spanish"
  #   humanized_language_list(nil) => ""
  def humanized_language_list(codes)
    codes_array = Array(codes).map(&:to_s).map(&:strip).reject(&:blank?)
    return "" if codes_array.empty?

    lookup = broker_language_lookup
    names = codes_array.map do |code|
      lookup[code.downcase] || code.upcase
    end

    names.to_sentence
  end

  # Accept either a broker role, a profile, or an array of ISO codes and return a
  # humanized language list. Encapsulates nil/shape checks so views stay thin.
  def humanized_language_list_for(subject)
    codes = if subject.is_a?(Array)
              subject
            elsif subject.respond_to?(:broker_agency_profile)
              subject.broker_agency_profile&.languages_spoken
            elsif subject.respond_to?(:languages_spoken)
              subject.languages_spoken
            end

    humanized_language_list(codes)
  end

  private

  def broker_language_lookup
    @broker_language_lookup ||= LanguageList::COMMON_LANGUAGES.each_with_object({}) do |li, memo|
      key = li.iso_639_1.to_s.downcase
      memo[key] = (li.common_name.present? ? li.common_name : li.name)
    end
  end
end
