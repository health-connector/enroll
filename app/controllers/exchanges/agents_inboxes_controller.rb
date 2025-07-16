class Exchanges::AgentsInboxesController < InboxesController
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
