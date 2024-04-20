# frozen_string_literal: true

module IndividualMarket
  class DocumentsController < ApplicationController
    before_action :set_person, only: [:fed_hub_request, :enrollment_verification, :update_verification_type, :extend_due_date]
    before_action :add_type_history_element, only: [:update_verification_type, :fed_hub_request, :destroy]

    def update_verification_type
      family_member = FamilyMember.find(params[:family_member_id]) if params[:family_member_id].present?
      v_type = params[:verification_type]
      update_reason = params[:verification_reason]
      admin_action = params[:admin_action]
      reasons_list = VlpDocument::VERIFICATION_REASONS + VlpDocument::ALL_TYPES_REJECT_REASONS + VlpDocument::CITIZEN_IMMIGR_TYPE_ADD_REASONS
      if (reasons_list).include?(update_reason)
        verification_result = @person.consumer_role.admin_verification_action(admin_action, v_type, update_reason)
        message = verification_result.is_a?(String) ? verification_result : "Person verification successfully approved."
        flash_message = { :success => message}
        update_documents_status(family_member) if family_member
      else
        flash_message = { :error => "Please provide a verification reason."}
      end

      respond_to do |format|
        format.html { redirect_to :back, :flash => flash_message }
      end
    end

    def enrollment_verification
      family = @person.primary_family
      if family.active_household.hbx_enrollments.verification_needed.any?
        family.active_household.hbx_enrollments.verification_needed.each(&:evaluate_individual_market_eligiblity)
        family.save!
        respond_to do |format|
          format.html do
            flash[:success] = "Enrollment group was completely verified."
            redirect_to :back
          end
        end
      else
        respond_to do |format|
          format.html do
            flash[:danger] = "Family does not have any active Enrollment to verify."
            redirect_to :back
          end
        end
      end
    end

    def fed_hub_request
      if params[:verification_type] == 'DC Residency'
        @person.consumer_role.invoke_residency_verification!
      else
        @person.consumer_role.redetermine_verification!(verification_attr)
      end
      respond_to do |format|
        format.html do
          hub = params[:verification_type] == 'DC Residency' ? 'Local Residency' : 'FedHub'
          flash[:success] = "Request was sent to #{hub}."
          redirect_to :back
        end
        format.js
      end
    end

    def extend_due_date
      @family_member = FamilyMember.find(params[:family_member_id])
      v_type = params[:verification_type]
      enrollment = find_enrollment

      if enrollment.present?
        process_enrollment(enrollment, v_type)
      else
        flash[:danger] = "Family Member does not have any unverified Enrollment to extend verification due date."
      end

      redirect_to :back
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
      @person&.consumer_role&.add_type_history_element(verification_type: verification_type,
                                                       action: action.split('_').join(' '),
                                                       modifier: actor,
                                                       update_reason: reason)
    end

    def update_documents_status(family_member)
      family = family_member.family
      family.update_family_document_status!
    end

    def verification_attr
      OpenStruct.new({:determined_at => Time.now,
                      :authority => "hbx"})
    end

    def find_enrollment
      @family_member.family.enrollments.verification_needed.where(:"hbx_enrollment_members.applicant_id" => @family_member.id).first
    end

    def process_enrollment(enrollment, v_type)
      add_type_history_element
      special_verification = @family_member.person.consumer_role.special_verifications.where(:verification_type => v_type).order_by(:created_at.desc).first
      new_date = calculate_new_date(special_verification, enrollment)
      create_special_verification(new_date, v_type)
      set_min_due_date_on_family
    end

    def calculate_new_date(special_verification, enrollment)
      if special_verification.present?
        flash[:success] = "Special verification period was extended for 30 days."
        special_verification.due_date.to_date + 30.days
      else
        flash[:success] = "You set special verification period for this Enrollment. Verification due date now is #{new_date.to_date}"
        (enrollment.submitted_at.to_date + 95.days) + 30.days
      end
    end

    def create_special_verification(new_date, v_type)
      sv = SpecialVerification.new(due_date: new_date, verification_type: v_type, updated_by: current_user.id, type: "admin")
      @family_member.person.consumer_role.special_verifications << sv
      @family_member.person.consumer_role.save!
    end

    def set_min_due_date_on_family
      family = @family_member.family
      family.update_attributes(min_verification_due_date: family.min_verification_due_date_on_family)
    end
  end
end
