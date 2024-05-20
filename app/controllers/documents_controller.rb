class DocumentsController < ApplicationController
  include L10nHelper

  before_action :fetch_record, only: [:authorized_download]
  before_action :set_document, only: [:destroy]
  respond_to :html, :js
  rescue_from ActionController::Redirecting::UnsafeRedirectError, with: :redirect_to_default

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

  def employees_template_download
    authorize current_user, :can_download_employees_template?

    begin
      bucket = env_bucket_name("templates")
      key = EnrollRegistry[:enroll_app].setting(:census_employees_template_file).item
      uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket}##{key}"
      send_data Aws::S3Storage.find(uri), get_options(params)
    rescue StandardError => e
      Rails.logger.error { "Error while downloading: #{e}" }
      redirect_to :back, :flash => { :error => l10n('exchange.download_failed') }
    end
  end

  def product_sbc_download
    authorize current_user, :can_download_sbc_documents?

    begin
      sbc_document = fetch_product_sbc_document || fetch_plan_sbc_document
      uri = sbc_document.identifier
      send_data Aws::S3Storage.find(uri), get_options(params)
    rescue StandardError => e
      Rails.logger.error { "Error while downloading: #{e}" }
      redirect_to :back, :flash => { :error => l10n('exchange.download_failed') }
    end
  end

  def employer_attestation_document_download
    employer_profile = BenefitSponsors::Organizations::Organization.employer_profiles.where(
      :"profiles._id" => BSON::ObjectId.from_string(params[:id])
    ).first.employer_profile

    authorize employer_profile, :employer_attestation_document_download?

    begin
      attestation_document = fetch_employer_profile_attestation_document(employer_profile)
      uri = attestation_document&.identifier
      send_data Aws::S3Storage.find(uri), get_options(params)
    rescue StandardError => e
      Rails.logger.error { "Error while downloading: #{e}" }
      redirect_to :back, :flash => { :error => l10n('exchange.download_failed') }
    end
  end

  private

  def env_bucket_name(bucket_name)
    aws_env = ENV['AWS_ENV'] || "qa"
    subdomain = EnrollRegistry[:enroll_app].setting(:subdomain).item
    "#{subdomain}-enroll-#{bucket_name}-#{aws_env}"
  end

  def fetch_product_sbc_document
    return unless params[:product_id]

    product = BenefitMarkets::Products::Product.find(params[:product_id])
    product.sbc_document
  end

  def fetch_plan_sbc_document
    return unless params[:plan_id]

    plan = Plan.find(params[:plan_id])
    plan.sbc_document
  end

  def fetch_employer_profile_attestation_document(employer_profile)
    return unless employer_profile&.employer_attestation.present?

    employer_profile.employer_attestation.employer_attestation_documents.find(params[:document_id])
  end

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

  def redirect_to_default
    redirect_to root_path
  end
end
