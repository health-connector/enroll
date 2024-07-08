class Exchanges::AgentsInboxesController < InboxesController
  def find_inbox_provider
    @inbox_provider = current_user.person
    @inbox_provider_name = "Agent"
  end

  def destroy
    authorize :agent

    @sent_box = true
    super
  end

  def show
    authorize :agent

    @sent_box = true
    super
  end
end
