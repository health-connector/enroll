# frozen_string_literal: true

# When a step reads or clicks an element while the page is being replaced, Chrome
# sometimes reports "unknown error: unhandled inspector error: Node with given id does
# not belong to the document" instead of a stale element error. Capybara only retries
# stale element errors, so the step fails at once. Retry this error the same way.
module RetryDetachedNodeErrors
  DETACHED_NODE_MESSAGE = "Node with given id does not belong to the document"

  protected

  def catch_error?(error, errors = nil)
    super || (error.is_a?(Selenium::WebDriver::Error::UnknownError) && error.message.include?(DETACHED_NODE_MESSAGE))
  end
end

Capybara::Node::Base.prepend(RetryDetachedNodeErrors)
