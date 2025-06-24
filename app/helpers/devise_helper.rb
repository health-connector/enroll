# frozen_string_literal: true

module DeviseHelper
  def devise_error_messages!
    return "" if resource.errors.empty?

    # Duplicate the hash to avoid "can't modify frozen Hash" error
    mutable_errors = resource.errors.messages.deep_dup
    mutable_errors[:username] = mutable_errors.delete(:oim_id) if mutable_errors.key?(:oim_id)

    messages = mutable_errors.map do |key, value|
      value.map { |v| content_tag(:li, "#{key.to_s.humanize} #{v}") }
    end.join

    html = <<-HTML
    <div class="alert alert-error module registration-rules" role="alert">
      <div class="text-center">
        <strong>
          #{l10n('devise.errors.message')}
        </strong>
      </div>
      <br/>
      <ul>#{messages}</ul>
    </div>
    HTML

    html.html_safe
  end
end
