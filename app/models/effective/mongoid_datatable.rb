module Effective
  class MongoidDatatable < Effective::Datatable
    delegate :current_user, :to => :@view

    def global_search_method
      :datatable_search
    end

    def authorize!
      Rails.logger.warn("PUNDIT") { "Access policy not specified for Effective Datatable: #{self.class.name}" }
      current_user.present?
    end

    protected

    def table_tool 
      @table_tool ||= MongoidDatatableTool.new(self, table_columns.reject { |_, col| col[:array_column] })
    end

    def active_record_collection?
      @active_record_collection ||= true
    end
  end
end
