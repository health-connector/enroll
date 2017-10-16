require 'curl'

module Notifier
  class NoticeKind
    include Mongoid::Document
    include Mongoid::Timestamps
    include AASM

    RECEIPIENTS = {
      "Employer" => "Notifier::MergeDataModels::EmployerProfile",
      "Employee" => "Notifier::MergeDataModels::EmployeeProfile",
      "Broker" => "Notifier::MergeDataModels::BrokerProfile"
    }

    field :title, type: String
    field :description, type: String
    field :identifier, type: String
    field :notice_number, type: String
    field :receipient, type: String, default: "Notifier::MergeDataModels::EmployerProfile"
    field :aasm_state, type: String, default: :draft

    embeds_one :cover_page
    embeds_one :template, class_name: "Notifier::Template"
    embeds_one :merge_data_model
    embeds_many :workflow_state_transitions, as: :transitional

    validates_presence_of :title, :notice_number, :receipient
    validates_uniqueness_of :notice_number

    before_save :set_data_elements

    scope :published,         ->{ any_in(aasm_state: ['published']) }
    scope :archived,          ->{ any_in(aasm_state: ['archived']) }

    def set_data_elements
      if template.present?
        template.data_elements = template.raw_body.scan(/\#\{([\w|\.]*)\}/).flatten.reject{|element| element.scan(/Settings/).any?}
      end
    end

    def receipient_class_name
      # receipient.constantize.class_name.underscore
      receipient.to_s.split('::').last.underscore.to_sym
    end

    def to_html(options = {})
      params = { receipient_class_name.to_sym => receipient.constantize.stubbed_object }

      if receipient_class_name.to_sym != :employer_profile
        params.merge!({employer_profile: receipient.constantize.stubbed_object})
      end

      Notifier::NoticeKindsController.new.render_to_string({
        :template => 'notifier/notice_kinds/template.html.erb', 
        :layout => false,
        :locals => { receipient: receipient.constantize.stubbed_object, notice_number: self.notice_number}
      }) + Notifier::NoticeKindsController.new.render_to_string({ 
        :inline => template.raw_body.gsub('${', '<%=').gsub('#{', '<%=').gsub('}','%>').gsub('[[', '<%').gsub(']]', '%>'),
        :layout => 'notifier/pdf_layout',
        :locals => params
      })
    end

    def save_html
      File.open(Rails.root.join("tmp", "notice.html"), 'wb') do |file|
        file << self.to_html({kind: 'pdf'})
      end
    end 
  
    def to_pdf
      WickedPdf.new.pdf_from_string(self.to_html({kind: 'pdf'}), pdf_options)
    end

    def generate_pdf_notice
      File.open(notice_path, 'wb') do |file|
        file << self.to_pdf
      end

      attach_envelope
      non_discrimination_attachment
      # clear_tmp
    end

    def pdf_options
      {
        margin:  {
          top: 15,
          bottom: 28,
          left: 22,
          right: 22 
        },
        disable_smart_shrinking: true,
        dpi: 96,
        page_size: 'Letter',
        formats: :html,
        encoding: 'utf8',
        header: {
          content: ApplicationController.new.render_to_string({
            template: "notifier/notice_kinds/header_with_page_numbers.html.erb",
            layout: false,
            locals: {notice: self}
            }),
          }
      }
    end

    def notice_path
      Rails.root.join("public", "NoticeTemplate.pdf")
    end

    def non_discrimination_attachment
      join_pdfs [notice_path, Rails.root.join('lib/pdf_templates', 'ma_shop_non_discrimination_attachment.pdf')]
    end

    def attach_envelope
      join_pdfs [notice_path, Rails.root.join('lib/pdf_templates', 'ma_envelope_without_address.pdf')]
    end

    def join_pdfs(pdfs)
      pdf = File.exists?(pdfs[0]) ? CombinePDF.load(pdfs[0]) : CombinePDF.new
      pdf << CombinePDF.load(pdfs[1])
      pdf.save notice_path
    end

    # def self.markdown
    #   Redcarpet::Markdown.new(ReplaceTokenRenderer,
    #       no_links: true,
    #       hard_wrap: true,
    #       disable_indented_code_blocks: true,
    #       fenced_code_blocks: false,        
    #     )
    # end

    # # Markdown API: http://www.rubydoc.info/gems/redcarpet/3.3.4
    # def to_html
    #   self.markdown.render(template.body)
    # end

    def self.to_csv
      CSV.generate(headers: true) do |csv|
        csv << ['Notice Number', 'Title', 'Description', 'Receipient', 'Notice Template']

        all.each do |notice|
          csv << [notice.notice_number, notice.title, notice.description, notice.receipient, notice.template.try(:raw_body)]
        end
      end
    end

    aasm do
      state :draft, initial: true

      state :published
      state :archived

      event :publish, :after => :record_transition do
        transitions from: :draft,  to: :published,  :guard  => :can_be_published?
      end

      event :archive, :after => :record_transition do
        transitions from: [:published],  to: :archived
      end  
    end

    # Check if notice with same MPI indictor exists
    def can_be_published?
    end

    def record_transition
      self.workflow_state_transitions << WorkflowStateTransition.new(
        from_state: aasm.from_state,
        to_state: aasm.to_state
        )
    end
  end
end
