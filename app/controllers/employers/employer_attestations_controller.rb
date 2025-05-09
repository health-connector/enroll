class Employers::EmployerAttestationsController < ApplicationController

  before_action :find_employer, except: [:new]

  def edit
    authorize @employer_profile, :employer_attestation_edit?
    @documents = []
    @documents = @employer_profile.employer_attestation.employer_attestation_documents if @employer_profile.employer_attestation.present?
    @element_to_replace_id = params[:employer_actions_id]
  end

  def new
    authorize current_user, :employer_attestation_new?
    @document = Document.new
    respond_to do |format|
      format.js
    end
  end

  def verify_attestation
    authorize @employer_profile
    attestation = @employer_profile.employer_attestation
    @document = attestation.employer_attestation_documents.find(params[:employer_attestation_id])
  end

  def create
    authorize @employer_profile, :employer_attestation_create?
    @errors = []
    if params[:file]
      file = params[:file]
      doc_uri = Aws::S3Storage.save(file.tempfile.path, 'attestations')
      @employer_profile.create_employer_attestation unless @employer_profile.employer_attestation.present?
      if doc_uri.present?
        @employer_profile.employer_attestation.employer_attestation_documents.create(
          :identifier => doc_uri,
          :subject => file.original_filename,
          :title => file.original_filename,
          :size => file.size,
          :format => "application/pdf"
        )

        if @employer_profile.save
          flash[:notice] = "File Saved"
        else
          flash[:error] = "Could not save file. "# + errors.join(". ")
        end
      else
        flash[:error] = "Could not save the file in S3 storage"
      end
    else
      flash[:error] = "Please upload file"
    end

    redirect_to benefit_sponsors.profiles_employers_employer_profile_path(@employer_profile.id, :tab=>'documents')
  end

  def update
    authorize @employer_profile, :employer_attestation_update?
    attestation = @employer_profile.employer_attestation
    document = attestation.employer_attestation_documents.find(params[:employer_attestation_id])

    if document.present?
      document.submit_review(params)
      flash[:notice] = "Employer attestation updated successfully"
    else
      flash[:error] = "Failed: Unable to find attestation document."
    end

    redirect_to exchanges_hbx_profiles_path
  end

  def authorized_download
    authorize @employer_profile
    begin
      documents = @employer_profile.employer_attestation.employer_attestation_documents
      if authorized_to_download?
        uri = documents.find(params[:employer_attestation_id]).identifier
        send_data Aws::S3Storage.find(uri), get_options(params)
      else
       raise "Sorry! You are not authorized to download this document."
      end
    rescue => e
      redirect_back(fallback_location: root_path, :flash => {error: e.message})
    end
  end

  def delete_attestation_documents
    authorize @employer_profile
    begin
      @employer_profile.employer_attestation.employer_attestation_documents.where(:id =>params[:employer_attestation_id],:aasm_state => "submitted").destroy_all
      @employer_profile.employer_attestation.revert! if @employer_profile.employer_attestation.may_revert?
      redirect_to benefit_sponsors.profiles_employers_employer_profile_path(@employer_profile.id, :tab=>'documents')
    rescue => e
      render json: { status: 500, message: 'An error occured while deleting the employer attestation' }
    end
  end

  private

  def authorized_to_download?
    true
  end

  def get_options(params)
    options = {}
    options[:type] = params[:content_type] if params[:content_type]
    options[:filename] = params[:filename] if params[:filename]
    options[:disposition] = params[:disposition] if params[:disposition]
    options
  end

  def find_employer
    if params[:employer_attestation_id].present?
      org = ::BenefitSponsors::Organizations::Organization.where(:"profiles.employer_attestation.employer_attestation_documents._id" => BSON::ObjectId.from_string(params[:employer_attestation_id])).first
      org ||= Organization.where(:"employer_profile.employer_attestation.employer_attestation_documents._id" => BSON::ObjectId.from_string(params[:employer_attestation_id])).first
      @employer_profile = org.employer_profile
    elsif params[:id].present?
      @employer_profile = EmployerProfile.find(params[:id]) || ::BenefitSponsors::Organizations::Profile.find(params[:id])
    else
      @employer_profile = Organization.where(:legal_name => params["document"]["creator"]).first.try(:employer_profile)
      @employer_profile ||= ::BenefitSponsors::Organizations::Organization.where(:legal_name => params["document"]["creator"]).first.employer_profile
    end
    render file: 'public/404.html', status: 404 if @employer_profile.blank?
  end
end
