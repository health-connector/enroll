# frozen_string_literal: true

require 'html_scrubber_util'
module L10nHelper
  prepend ActionView::Helpers::TranslationHelper
  include HtmlScrubberUtil

  # The `l10n` method is used for text localization. It returns a (sanitized) translation for the given key. Interpolation
  # placeholders are accommodated, via the underlying Rails I18n functionality
  # (https://guides.rubyonrails.org/i18n.html#passing-variables-to-translations), by passing vals to inject in the
  # `interpolated_keys` hash. If the translation key is blank and a `blank_default` key is provided in the
  # `interpolated_keys` hash, it uses the `blank_default` as the translation key. If the translation for a given key is
  # missing, the returned val is a human-readable default interpretation of the key.
  #
  # @param translation_key [String] the key for which to fetch the translation.
  # @param interpolated_keys [Hash] a hash of keys to be interpolated in the translation text. It can also contain a `:blank_default` key to be used when the `translation_key` is blank.
  # @return [String] the translated and sanitized string.
  def l10n(translation_key, interpolated_keys = {})
    translation_key = interpolated_keys[:blank_default] if translation_key.blank? && interpolated_keys.key?(:blank_default)

    result = fetch_translation(translation_key.to_s, interpolated_keys)

    sanitize_result(result, translation_key)
  rescue I18n::MissingTranslationData, RuntimeError => e
    handle_missing_translation(translation_key, e)
  end

  private

  def fetch_translation(translation_key, interpolated_keys)
    options = interpolated_keys.present? ? interpolated_keys.merge(default: default_translation(translation_key)) : {}

    # NOTE: Due to a caching issue in Rails 6.1, the `MISSING_TRANSLATION` object from
    #   `ActionView::Helpers::TranslationHelper` is cached in the I18n cache and read back as a
    #   different object. This issue occurs when calling `t(translation_key, default: translation_key.to_s&.gsub(/\W+/, '')&.titleize)`
    #   twice, where the value is returned back as a different object the second time. This issue might be fixed in Rails 7.0.4.
    #   Using `I18n.t` instead of `t` can lead to issues related to short naming of the translation key like l10n('.welcome_to_site_sub_header').
    #   Therefore, we are using `t` method with `raise: true` option to avoid the caching issue and returning the titleized translation key if the translation is missing.
    t(translation_key, **options, raise: true)
  end

  def sanitize_result(result, translation_key)
    return translation_key.to_s unless result.respond_to?(:html_safe)

    sanitize_html(result)
  end

  def handle_missing_translation(translation_key, error)
    Rails.logger.error {"#L10nHelper missing translation for key: #{translation_key}, error: #{error.inspect}"}
    sanitize_result(default_translation(translation_key), translation_key)
  end

  def default_translation(translation_key)
    translation_key.to_s&.gsub(/\W+/, '')&.titleize
  end
end
