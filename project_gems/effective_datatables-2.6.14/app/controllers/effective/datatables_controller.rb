# frozen_string_literal: true

module Effective
  class DatatablesController < ApplicationController
    skip_log_page_views quiet: true if defined?(EffectiveLogging)

    # This will respond to both a GET and a POST
    def show
      datatable_params[:custom_attributes].permit! if datatable_params[:custom_attributes].presence
      datatable_params[:attributes].permit! if datatable_params[:attributes].presence
      datatable_params[:scopes].permit! if datatable_params[:scopes].presence

      attributes = (datatable_params[:attributes].presence || {}).merge(referer: request.referer).merge(custom_attributes: datatable_params.try(:custom_attributes, []))
      scopes = (datatable_params[:scopes].presence || datatable_params[:custom_attributes].presence || {})

      @datatable = find_datatable(params[:id]).try(:new, attributes.merge(scopes).to_hash)
      @datatable.view = view_context unless @datatable.nil?

      EffectiveDatatables.authorized?(@datatable, self, :index, @datatable.try(:collection_class) || @datatable.try(:class))

      respond_to do |format|
        format.html
        format.json do
          if Rails.env.production?
            render :json => begin
              @datatable.to_json
            rescue StandardError
              error_json
            end
          else
            render :json => @datatable.to_json
          end
        end
      end
    end

    private

    def datatable_params
      permitted = [
        :draw, :start, :length, :id, :controller, :action, :format,
        { search: [:value, :regex] }
      ]

      column_structure = [:data, :name, :searchable, :orderable, :visible, { search: [:value, :regex] }]

      columns = params[:columns]&.keys || []
      columns_permitted = columns.index_with { column_structure }

      orders = params[:order]&.keys || []
      order_permitted = orders.index_with { [:column, :dir] }

      params.permit(
        *permitted,
        columns: columns_permitted,
        order: order_permitted,
        custom_attributes: {},
        attributes: {}
      )
    end

    def find_datatable(id)
      id_plural = id.pluralize == id && id.singularize != id
      klass = "effective/datatables/#{id}".classify

      (id_plural ? klass.pluralize : klass).safe_constantize
    end

    def error_json
      {
        :draw => params[:draw].to_i,
        :data => [],
        :recordsTotal => 0,
        :recordsFiltered => 0,
        :aggregates => [],
        :charts => {}
      }.to_json
    end

  end
end
