module Notifier
  class NoticeKindsController < Notifier::ApplicationController

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

    layout 'notifier/single_column'

    def index
      authorize ::Notifier::NoticeKind

      @notice_kinds = Notifier::NoticeKind.all
      @datatable = Effective::Datatables::NoticesDatatable.new
      @errors = []
    end

    def show
      authorize ::Notifier::NoticeKind

      if params['id'] == 'upload_notices'
        redirect_to notice_kinds_path
      end
    end

    def new
      authorize ::Notifier::NoticeKind

      @notice_kind = Notifier::NoticeKind.new
      @notice_kind.template = Notifier::Template.new
    end

    def edit
      authorize ::Notifier::NoticeKind

      @notice_kind = Notifier::NoticeKind.find(params[:id])
      render :layout => 'notifier/application'
    end

    def create
      authorize ::Notifier::NoticeKind

      template = Template.new(notice_params.delete('template'))
      notice_kind = NoticeKind.new(notice_params)
      notice_kind.template = template

      if notice_kind.save
        flash[:notice] = 'Notice created successfully'
        redirect_to notice_kinds_path
      else
        @errors = notice_kind.errors.messages

        @notice_kinds = Notifier::NoticeKind.all
        @datatable = Effective::Datatables::NoticesDatatable.new

        render :action => 'index'
      end
    end

    def update
      authorize ::Notifier::NoticeKind

      notice_kind = Notifier::NoticeKind.find(params['id'])
      notice_kind.update_attributes(notice_params)

      flash[:notice] = 'Notice content updated successfully'
      redirect_to notice_kinds_path
    end

    def preview
      authorize ::Notifier::NoticeKind

      notice_kind = Notifier::NoticeKind.find(params[:id])
      notice_kind.generate_pdf_notice

      send_file "#{Rails.root}/tmp/#{notice_kind.title.titleize.gsub(/\s+/, '_')}.pdf",
                :type => 'application/pdf',
                :disposition => 'inline'
    end

    def delete_notices
      authorize ::Notifier::NoticeKind

      Notifier::NoticeKind.where(:id.in => params['ids']).each do |notice|
        notice.delete
      end

      flash[:notice] = 'Notices deleted successfully'
      redirect_to notice_kinds_path
    end

    def download_notices
      authorize ::Notifier::NoticeKind

      send_data Notifier::NoticeKind.to_csv,
        :filename => "notices_#{TimeKeeper.date_of_record.strftime('%m_%d_%Y')}.csv",
        :disposition => 'attachment',
        :type => 'text/csv'
    end

    def upload_notices
      authorize ::Notifier::NoticeKind

      notices = Roo::Spreadsheet.open(params[:file].tempfile.path)
      @errors = []

      if params[:file] && !validate_file_upload(params[:file], FileUploadValidator::CSV_TYPES)
        render :action => 'index'
        return
      end

      notices.each do |notice_row|
        next if notice_row[0] == 'Notice Number'

        if Notifier::NoticeKind.where(notice_number: notice_row[0]).blank?
          notice = Notifier::NoticeKind.new(notice_number: notice_row[0], title: notice_row[1], description: notice_row[2], recipient: notice_row[3], event_name: notice_row[4])
          notice.template = Template.new(raw_body: notice_row[5])
          unless notice.save
            @errors << "Notice #{notice_row[0]} got errors: #{notice.errors.to_s}"
          end
        else
          @errors << "Notice #{notice_row[0]} already exists."
        end
      end

      if @errors.empty?
        flash[:notice] = 'Notices loaded successfully.'
      end

      @notice_kinds = Notifier::NoticeKind.all
      @datatable = Effective::Datatables::NoticesDatatable.new

      render :action => 'index'
    end

    def get_tokens
      authorize ::Notifier::NoticeKind

      token_builder = builder_param.constantize.new
      tokens = token_builder.editor_tokens
      # placeholders = token_builder.place_holders

      respond_to do |format|
        format.html
        format.json { render json: {tokens: tokens} }
      end
    end

    def get_placeholders
      authorize ::Notifier::NoticeKind
      placeholders = Notifier::MergeDataModels::EmployerProfile.new.place_holders

      respond_to do |format|
        format.html
        format.json {render json: placeholders}
      end
    end

    private

    def notice_params
      params.require(:notice_kind).permit(:title, :description, :notice_number, :recipient, :event_name, {:template => [:raw_body]})
    end

    def builder_param
      if params['builder'].present?
        model = params['builder'].camelize
        Notifier::NoticeKind::MODEL_CLASS_MAPPING[model]
      else
        'Notifier::MergeDataModels::EmployerProfile'
      end
    end
  end
end
