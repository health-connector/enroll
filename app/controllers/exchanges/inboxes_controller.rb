# frozen_string_literal: true

module Exchanges
  class InboxesController < InboxesController
    def destroy
      @sent_box = true
      super
    end

    def show
      @sent_box = true
      super
    end

    private

    def find_inbox_provider
      authorize HbxProfile, :inbox?

      @inbox_provider = HbxProfile.find(params["id"])
      @inbox_provider_name = "System Admin"
    end
  end
end
