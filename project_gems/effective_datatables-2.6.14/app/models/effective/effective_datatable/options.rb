# This is extended as class level into Datatable

module Effective
  module EffectiveDatatable
    module Options
      def initialize_datatable_options
        @table_columns = _initialize_datatable_options(@table_columns)
      end

      def initialize_scope_options
        @scopes = _initialize_scope_options(@scopes)
      end

      def initialize_chart_options
        @charts = _initialize_chart_options(@charts)
      end

      def quote_sql(name)
        collection_class.connection.quote_column_name(name)
      rescue StandardError
        name
      end

      protected

      # The scope DSL is
      # scope :start_date, default_value, options: {}
      #
      # The value might already be assigned, but if not, we have to assign the default to attributes

      # A scope comes to us like {:start_date => {default: Time.zone.now, filter: {as: :select, collection: ... input_html :}}}
      # We want to make sure an input_html: { value: default } exists
      def _initialize_scope_options(scopes)
        (scopes || []).each do |name, options|
          value = attributes.key?(name) ? attributes[name] : options[:default]

          if (options[:fallback] || options[:presence]) && attributes[name].blank? && attributes[name] != false
            attributes[name] = options[:default]
            value = options[:default]
          end

          options[:filter] ||= {}
          options[:filter][:input_html] ||= {}
          options[:filter][:input_html][:value] = value
          options[:filter][:selected] = value
        end
      end

      def _initialize_chart_options(charts)
        charts
      end

      def _initialize_datatable_options(cols)
        sql_table = begin
          collection.table
        rescue StandardError
          nil
        end

        # Here we identify all belongs_to associations and build up a Hash like:
        # {user: {foreign_key: 'user_id', klass: User}, order: {foreign_key: 'order_id', klass: Effective::Order}}
        belong_tos = begin
          collection.klass.reflect_on_all_associations(:belongs_to)
        rescue StandardError
          []
        end.inject({}) do |retval, bt|
          if bt.options[:polymorphic]
            retval[bt.name.to_s] = {foreign_key: bt.foreign_key, klass: bt.name, polymorphic: true}
          else
            klass = bt.klass || begin
              bt.foreign_type.sub('_type', '').classify.constantize
            rescue StandardError
              nil
            end
            retval[bt.name.to_s] = {foreign_key: bt.foreign_key, klass: klass} if bt.foreign_key.present? && klass.present?
          end

          retval
        end

        # Figure out has_manys and has_many_belongs_to_many's
        has_manys = {}
        has_and_belongs_to_manys = {}

        if defined?(::ActiveRecord::Base) && !collection.is_a?(::ActiveRecord::Base)
          begin
            collection.klass.reflect_on_all_associations
          rescue StandardError
            []
          end.each do |reflect|
            if reflect.macro == :has_many
              klass = reflect.klass || reflect.build_association({}).class
              has_manys[reflect.name.to_s] = {klass: klass}
            elsif reflect.macro == :has_and_belongs_to_many
              klass = reflect.klass || reflect.build_association({}).class
              has_and_belongs_to_manys[reflect.name.to_s] = {klass: klass}
            end
          end
        end

        table_columns = cols.each_with_index do |(name, _), index|
          # If this is a belongs_to, add an :if clause specifying a collection scope if
          cols[name][:if] ||= proc { attributes[belong_tos[name][:foreign_key]].blank? } if belong_tos.key?(name)

          sql_column = begin
            collection.columns
          rescue StandardError
            []
          end.find do |column|
            column.name == name.to_s || (belong_tos.key?(name) && column.name == belong_tos[name][:foreign_key])
          end

          cols[name][:array_column] ||= false
          cols[name][:array_index] = index # The index of this column in the collection, regardless of hidden table_columns
          cols[name][:name] ||= name
          cols[name][:label] ||= name.titleize
          cols[name][:column] ||= sql_table && sql_column ? "#{quote_sql(sql_table.name)}.#{quote_sql(sql_column.name)}" : name
          cols[name][:width] ||= nil
          cols[name][:sortable] = false if cols[name][:sortable].nil?
          cols[name][:visible] = true if cols[name][:visible].nil?

          # Type
          cols[name][:type] ||= cols[name][:as]  # Use as: or type: interchangeably

          cols[name][:type] ||= if belong_tos.key?(name)
                                  if belong_tos[name][:polymorphic]
                                    :belongs_to_polymorphic
                                  else
                                    :belongs_to
                                  end
                                elsif has_manys.key?(name)
                                  :has_many
                                elsif has_and_belongs_to_manys.key?(name)
                                  :has_and_belongs_to_many
                                elsif cols[name][:bulk_actions_column]
                                  :bulk_actions_column
                                elsif name.include?('_address') && defined?(EffectiveAddresses) && begin
                                  collection_class.new
                                rescue StandardError
                                  nil
                                end.respond_to?(:effective_addresses)
                                  :effective_address
                                elsif name == 'id' && defined?(EffectiveObfuscation) && collection.respond_to?(:deobfuscate)
                                  :obfuscated_id
                                elsif name == 'roles' && defined?(EffectiveRoles) && collection.respond_to?(:with_role)
                                  :effective_roles
                                elsif sql_column.try(:type).present?
                                  sql_column.type
                                elsif name.end_with?('_id')
                                  :integer
                                else
                                  :string # When in doubt
                                end


          cols[name][:class] = "col-#{cols[name][:type]} col-#{name} #{cols[name][:class]}".strip

          # Formats
          cols[name][:format] = :non_formatted_integer if name == 'id' || name.include?('year') || name.end_with?('_id')

          # Sortable - Disable sorting on these types
          cols[name][:sortable] = false if [:has_many, :effective_address, :obfuscated_id].include?(cols[name][:type])

          # EffectiveRoles, if you do table_column :roles, everything just works
          if cols[name][:type] == :effective_roles
            cols[name][:column] = sql_table.present? ? "#{quote_sql(sql_table.name)}.#{quote_sql('roles_mask')}" : name
          end

          cols[name][:sql_as_column] = true if sql_table.present? && sql_column.blank? && !cols[name][:array_column] # This is a SELECT AS column, or a JOIN column

          cols[name][:filter] = initialize_table_column_filter(cols[name], belong_tos[name], has_manys[name], has_and_belongs_to_manys[name])

          cols[name][:partial_local] ||= (sql_table.try(:name) || cols[name][:partial].split('/').last(2).first.presence || 'obj').singularize.to_sym if cols[name][:partial]
        end

        # After everything is initialized
        # Compute any col[:if] and assign an index
        count = 0
        table_columns.each do |name, col|
          if display_column?(col)
            col[:index] = count
            count += 1
          else
            # deleting rather than using `table_columns.select` above in order to maintain
            # this hash as a type of HashWithIndifferentAccess
            table_columns.delete(name)
          end
        end
      end

      def initialize_table_column_filter(column, belongs_to, has_many, has_and_belongs_to_manys)
        filter = column[:filter]
        col_type = column[:type]
        sql_column = column[:column].to_s.upcase

        return {as: :null} if filter == false

        filter = {as: filter.to_sym} if filter.is_a?(String)
        filter = {} unless filter.is_a?(Hash)

        # This is a fix for passing filter[:selected] == false, it needs to be 'false'
        filter[:selected] = filter[:selected].to_s unless filter[:selected].nil?

        # Allow :values or :collection to be used interchangeably
        filter[:collection] ||= filter[:values] if filter.key?(:values)

        # Allow :as or :type to be used interchangeably
        filter[:as] ||= filter[:type] if filter.key?(:type)

        # If you pass a collection, just assume it's a select
        filter[:as] ||= :select if filter.key?(:collection) && col_type != :belongs_to_polymorphic

        # Fuzzy by default throughout
        filter[:fuzzy] = true unless filter.key?(:fuzzy)

        # Check if this is an aggregate column
        filter[:sql_operation] = :having if ['SUM(', 'COUNT(', 'MAX(', 'MIN(', 'AVG('].any? { |str| sql_column.include?(str) }

        case col_type
        when :belongs_to
          {
            as: :select,
            collection: (
              if belongs_to[:klass].respond_to?(:datatables_filter)
                proc { belongs_to[:klass].datatables_filter }
              else
                proc { belongs_to[:klass].all.map { |obj| [obj.to_s, obj.id] }.sort { |x, y| x[0] <=> y[0] } }
              end
            )
          }
        when :belongs_to_polymorphic
          {as: :grouped_select, polymorphic: true, collection: {}}
        when :has_many
          {
            as: :select,
            multiple: true,
            collection: (
              if has_many[:klass].respond_to?(:datatables_filter)
                proc { has_many[:klass].datatables_filter }
              else
                proc { has_many[:klass].all.map { |obj| [obj.to_s, obj.id] }.sort { |x, y| x[0] <=> y[0] } }
              end
            )
          }
        when :has_and_belongs_to_many
          {
            as: :select,
            multiple: true,
            collection: (
              if has_and_belongs_to_manys[:klass].respond_to?(:datatables_filter)
                proc { has_and_belongs_to_manys[:klass].datatables_filter }
              else
                proc { has_and_belongs_to_manys[:klass].all.map { |obj| [obj.to_s, obj.id] }.sort { |x, y| x[0] <=> y[0] } }
              end
            )
          }
        when :effective_address
          {as: :string}
        when :effective_roles
          {as: :select, collection: EffectiveRoles.roles}
        when :obfuscated_id
          {as: :obfuscated_id}
        when :integer
          {as: :number}
        when :boolean
          if EffectiveDatatables.boolean_format == :yes_no
            {as: :boolean, collection: [['Yes', true], ['No', false]] }
          else
            {as: :boolean, collection: [['true', true], ['false', false]] }
          end
        when :datetime
          {as: :datetime}
        when :date
          {as: :date}
        when :bulk_actions_column
          {as: :bulk_actions_column}
        else
          {as: :string}
        end.merge(filter.symbolize_keys)
      end

      private

      def display_column?(col)
        if col[:if].respond_to?(:call)
          (view || self).instance_exec(&col[:if])
        else
          col.fetch(:if, true)
        end
      end
    end
  end
end
