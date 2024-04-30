class DocumentsController < ApplicationController
  before_action :fetch_record, only: [:authorized_download]
  before_action :set_document, only: [:destroy]
  respond_to :html, :js

  def download
    bucket = params[:bucket]
    key = params[:key]
    uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket}##{key}"
    send_data Aws::S3Storage.find(uri), get_options(params)
  end

  def authorized_download
    authorize @record, :can_download_document?

    begin
      relation_id = params[:relation_id]
      documents = @record.documents
      uri = documents.find(relation_id).identifier
      send_data Aws::S3Storage.find(uri), get_options(params)
    rescue => e
      redirect_to(:back, :flash => {error: e.message})
    end
  end

  def show_docs
    if current_user.has_hbx_staff_role?
      session[:person_id] = params[:person_id]
      set_current_person
      @person.primary_family.active_household.hbx_enrollments.verification_needed.each do |enrollment|
        enrollment.update_attributes(:review_status => "in review")
      end
    end
    redirect_to verification_insured_families_path
  end

  def destroy
    authorize @person, :can_delete_document?

    @document.delete
    family_member = FamilyMember.find(params[:family_member_id])
    family_member.family.update_family_document_status!
    respond_to do |format|
      format.html { redirect_to verification_insured_families_path }
      format.js
    end
  end

  private

  def fetch_record
    model_id = params[:model_id]
    model = params[:model].camelize
    model_klass = Document::MODEL_CLASS_MAPPING[model]

    raise "Sorry! Invalid Request" unless model_klass

    @record = model_klass.find(model_id)
  end

  def get_options(params)
    options = {}
    options[:content_type] = params[:content_type] if params[:content_type]
    options[:filename] = params[:filename] if params[:filename]
    options[:disposition] = params[:disposition] if params[:disposition]
    options
  end

  def set_document
    set_person
    @document = @person.consumer_role.vlp_documents.find(params[:id])
  end

  def set_person
    @person = Person.find(params[:person_id]) if params[:person_id]
  end

  def file_path(file)
    file.tempfile.path
  end

  def file_name(file)
    file.original_filename
  end
end
