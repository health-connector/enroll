# frozen_string_literal: true

module Effective
  module EffectiveDatatable
    module Dsl
      module Datatable
        # Instance Methods inside the datatable do .. end block
        def default_order(name, direction = :asc)
          @default_order = {name => direction}
        end

        def default_entries(entries)
          @default_entries = entries
        end

        def table_column(name, options = {}, _proc = nil, &block)
          if block_given?
            raise "You cannot use partial: ... with the block syntax" if options[:partial] && !options[:type] == :actions
            raise "You cannot use proc: ... with the block syntax" if options[:proc]

            options[:block] = block
          end
          raise "You cannot use both partial: ... and proc: ..." if options[:partial] && options[:proc]

          (@table_columns ||= HashWithIndifferentAccess.new)[name] = options
        end

        def array_column(name, options = {}, proc = nil, &block)
          table_column(name, options.merge!(array_column: true), proc, &block)
        end

        def actions_column(options = {}, proc = nil, &block)
          raise 'first parameter to actions_column should be a hash' unless options.is_a?(Hash)

          show = options.fetch(:show, begin
            EffectiveDatatables.actions_column[:show]
          rescue StandardError
            false
          end)
          edit = options.fetch(:edit, begin
            EffectiveDatatables.actions_column[:edit]
          rescue StandardError
            false
          end)
          destroy = options.fetch(:destroy, begin
            EffectiveDatatables.actions_column[:destroy]
          rescue StandardError
            false
          end)
          unarchive = options.fetch(:unarchive, begin
            EffectiveDatatables.actions_column[:unarchive]
          rescue StandardError
            false
          end)
          name = options.fetch(:name, 'actions')

          opts = {
            type: :actions,
            sortable: false,
            filter: false,
            responsivePriority: 0,
            partial_locals: { show_action: show, edit_action: edit, destroy_action: destroy, unarchive_action: unarchive }
          }.merge(options)

          opts[:partial_local] ||= :resource unless opts[:partial].present?
          opts[:partial] ||= '/effective/datatables/actions_column' unless proc.present?

          table_column(name, opts, proc, &block)
        end

        def bulk_actions_column(options = {}, proc = nil, &block)
          raise 'first parameter to bulk_actions_column should be a hash' unless options.is_a?(Hash)

          name = options.fetch(:name, 'bulk_actions')
          resource_method = options.fetch(:resource_method, :to_param)

          opts = {
            bulk_actions_column: true,
            label: '',
            partial_local: :resource,
            partial: '/effective/datatables/bulk_actions_column',
            partial_locals: { resource_method: resource_method },
            sortable: false,
            dropdown_partial: '/effective/datatables/bulk_actions_dropdown',
            dropdown_block: block
          }.merge(options)

          table_column(name, opts, proc)
        end

        def aggregate(name, options = {}, &block)
          if block_given?
            raise "You cannot use proc: ... with the block syntax" if options[:proc]

            options[:block] = block
          end

          (@aggregates ||= HashWithIndifferentAccess.new)[name] = options
        end
      end
    end
  end
end
