module IndividualMarket
  class DocumentsController < ApplicationController
    before_action :set_person, only: [:update_verification_type]
    before_action :add_type_history_element, only: [:update_verification_type]

    def update_verification_type
      v_type = params[:verification_type]
      update_reason = params[:verification_reason]
      admin_action = params[:admin_action]
      family_member = FamilyMember.find(params[:family_member_id]) if params[:family_member_id].present?
      reasons_list = VlpDocument::VERIFICATION_REASONS + VlpDocument::ALL_TYPES_REJECT_REASONS + VlpDocument::CITIZEN_IMMIGR_TYPE_ADD_REASONS
      if (reasons_list).include? (update_reason)
        verification_result = @person.consumer_role.admin_verification_action(admin_action, v_type, update_reason)
        message = (verification_result.is_a? String) ? verification_result : "Person verification successfully approved."
        flash_message = { :success => message}
        update_documents_status(family_member) if family_member
      else
        flash_message = { :error => "Please provide a verification reason."}
      end

      respond_to do |format|
        format.html { redirect_to :back, :flash => flash_message }
      end
    end

    private

    def set_person
      @person = Person.find(params[:person_id]) if params[:person_id]
    end

    def add_type_history_element
      actor = current_user ? current_user.email : "external source or script"
      verification_type = params[:verification_type]
      action = params[:admin_action] || params[:action]
      action = "Delete #{params[:doc_title]}" if action == "destroy"
      reason = params[:verification_reason]
      if @person
        @person.consumer_role.add_type_history_element(verification_type: verification_type,
                                                       action: action.split('_').join(' '),
                                                       modifier: actor,
                                                       update_reason: reason)
      end
    end

    def update_documents_status(family_member)
      family = family_member.family
      family.update_family_document_status!
    end
  end
end
