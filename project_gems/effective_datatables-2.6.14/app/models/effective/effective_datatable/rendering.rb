# This is extended as class level into Datatable

module Effective
  module EffectiveDatatable
    module Rendering
      BLANK = ''.freeze

      protected

      # So the idea here is that we want to do as much as possible on the database in ActiveRecord
      # And then run any array_columns through in post-processed results
      def table_data
        col = collection

        if active_record_collection?
          col = table_tool.order(col)
          col = table_tool.search(col)

          self.display_records = active_record_collection_size(col) if table_tool.search_terms.present? && array_tool.search_terms.blank?
        end

        if array_tool.search_terms.present?
          col = arrayize(col)
          col = array_tool.search(col)
          self.display_records = col.size
        end

        if array_tool.order_by_column.present?
          col = arrayize(col)
          col = array_tool.order(col)
        end

        self.display_records ||= total_records

        if col.is_a?(Array)
          col = array_tool.paginate(col)
        else
          col = table_tool.paginate(col)
          col = arrayize(col)
        end

        self.format(col)
        col = finalize(col)
      end

      def arrayize(collection)
        return collection if @arrayized  # Prevent the collection from being arrayized more than once

        @arrayized = true

        # We want to use the render :collection for each column that renders partials
        rendered = {}
        (display_table_columns || table_columns).each do |name, opts|
          next unless opts[:partial] && opts[:visible]

          locals = HashWithIndifferentAccess.new(
            datatable: self,
            table_column: table_columns[name],
            controller_namespace: controller_namespace,
            show_action: (opts[:partial_locals] || {})[:show_action],
            edit_action: (opts[:partial_locals] || {})[:edit_action],
            destroy_action: (opts[:partial_locals] || {})[:destroy_action],
            unarchive_action: (opts[:partial_locals] || {})[:unarchive_action]
          )

          locals.merge!(opts[:partial_locals]) if opts[:partial_locals]

          add_actions_column_locals(locals) if opts[:type] == :actions

          rendered[name] = (render(
            :partial => opts[:partial],
            :as => opts[:partial_local],
            :collection => collection,
            :formats => :html,
            :locals => locals,
            :spacer_template => '/effective/datatables/spacer_template'
          ) || '').split('EFFECTIVEDATATABLESSPACER')
        end

        collection.each_with_index.map do |obj, index|
          (display_table_columns || table_columns).map do |name, opts|

            if opts[:visible] == false
              BLANK
            elsif opts[:block]
              begin
                view.instance_exec(obj, collection, self, &opts[:block])
              rescue NoMethodError => e
                if opts[:type] == :actions && e.message == 'super called outside of method'
                  rendered[name][index]
                else
                  raise(e)
                end
              end
            elsif opts[:proc]
              view.instance_exec(obj, collection, self, &opts[:proc])
            elsif opts[:partial]
              rendered[name][index]
            elsif opts[:type] == :belongs_to
              begin
                obj.send(name)
              rescue StandardError
                nil
              end.to_s
            elsif opts[:type] == :belongs_to_polymorphic
              begin
                obj.send(name)
              rescue StandardError
                nil
              end.to_s
            elsif opts[:type] == :has_many
              begin
                obj.send(name).map { |obj| obj.to_s }.join('<br>')
              rescue StandardError
                BLANK
              end
            elsif opts[:type] == :has_and_belongs_to_many
              begin
                obj.send(name).map { |obj| obj.to_s }.join('<br>')
              rescue StandardError
                BLANK
              end
            elsif opts[:type] == :bulk_actions_column
              BLANK
            elsif opts[:type] == :year
              obj.send(name).try(:year)
            elsif opts[:type] == :obfuscated_id
              begin
                obj.send(:to_param)
              rescue StandardError
                nil
              end.to_s
            elsif opts[:type] == :effective_address
              begin
                Array(obj.send(name))
              rescue StandardError
                []
              end
            elsif opts[:type] == :effective_roles
              begin
                obj.send(:roles)
              rescue StandardError
                []
              end
            elsif obj.is_a?(Array) # Array backed collection
              obj[opts[:array_index]]
            elsif opts[:sql_as_column]
              obj[name]
            else
              obj.send(name)
            end
          rescue StandardError => e
            Rails.env.production? ? obj.try(:[], name) : raise(e)

          end
        end
      end

      def format(collection)
        collection.each do |row|
          (display_table_columns || table_columns).each_with_index do |(name, opts), index|
            value = row[index]
            next if value.nil? || value == BLANK || opts[:visible] == false
            next if opts[:block] || opts[:partial] || opts[:proc]

            row[index] = value.to_s if opts[:sql_as_column]

            case (opts[:format] || opts[:type])
            when :belongs_to, :belongs_to_polymorphic
              row[index] = value.to_s
            when :has_many
              if value.is_a?(Array)
                row[index] = if value.length == 0
                               BLANK
                             elsif value.length == 1
                               value.first.to_s
                             elsif opts[:sentence]
                               value.map { |v| v.to_s }.to_sentence
                             else
                               value.map { |v| v.to_s }.join('<br>')
                             end
              end
            when :effective_address
              row[index] = value.map { |addr| addr.to_html }.join('<br>')
            when :effective_roles
              row[index] = value.join(', ')
            when :datetime
              row[index] = begin
                value.strftime(EffectiveDatatables.datetime_format)
              rescue StandardError
                BLANK
              end
            when :date
              row[index] = begin
                value.strftime(EffectiveDatatables.date_format)
              rescue StandardError
                BLANK
              end
            when :price
              # This is an integer value, "number of cents"
              raise 'column type: price expects an Integer representing the number of cents' unless value.is_a?(Integer)

              row[index] = number_to_currency(value / 100.0)
            when :currency
              row[index] = number_to_currency(value || 0)
            when :percentage
              row[index] = number_to_percentage(value || 0)
            when :integer
              if EffectiveDatatables.integer_format.is_a?(Symbol)
                row[index] = view.instance_exec { public_send(EffectiveDatatables.integer_format, value) }
              elsif EffectiveDatatables.integer_format.respond_to?(:call)
                row[index] = view.instance_exec { EffectiveDatatables.integer_format.call(value) }
              end
            when :boolean
              if EffectiveDatatables.boolean_format == :yes_no && value == true
                row[index] = 'Yes'
              elsif EffectiveDatatables.boolean_format == :yes_no && value == false
                row[index] = 'No'
              end
            when :string
              row[index] = mail_to(value) if name == 'email'
            else
               # Nothing
            end
          end
        end

        collection
      end

      # This should return an Array of values the same length as table_data
      def aggregate_data(table_data)
        return false unless aggregates.present?

        values = table_data.transpose

        aggregates.map do |_name, options|
          (display_table_columns || table_columns).map.with_index do |(_name, column), index|

            if column[:visible] != true
              ''
            elsif (options[:block] || options[:proc]).respond_to?(:call)
              view.instance_exec(column, (values[index] || []), values, &(options[:block] || options[:proc]))
            else
              ''
            end
          end
        end
      end

      def add_actions_column_locals(locals)
        return unless active_record_collection?

        # Consider authorization levels first

        if locals[:show_action] == :authorize
          locals[:show_action] = begin
            EffectiveDatatables.authorized?(controller, :show, collection_class)
          rescue StandardError
            false
          end
        end

        if locals[:edit_action] == :authorize
          locals[:edit_action] = begin
            EffectiveDatatables.authorized?(controller, :edit, collection_class)
          rescue StandardError
            false
          end
        end

        if locals[:destroy_action] == :authorize
          locals[:destroy_action] = begin
            EffectiveDatatables.authorized?(controller, :destroy, collection_class)
          rescue StandardError
            false
          end
        end

        if locals[:unarchive_action] == :authorize
          locals[:unarchive_action] = begin
            EffectiveDatatables.authorized?(controller, :unarchive, collection_class)
          rescue StandardError
            false
          end
        end

        # Then we look at the routes to see if these actions _actually_ exist

        routes = Rails.application.routes

        begin
          resource = collection_class.new(id: 123)
          resource.define_singleton_method(:persisted?) { true }  # We override persisted? to get the correct action urls
        rescue StandardError => e
          return
        end

        if (locals[:show_action] == true || locals[:show_action] == :authorize_each) && !locals[:show_path]
          # Try our namespace
          url = begin
            view.polymorphic_path([*controller_namespace, resource])
          rescue StandardError
            false
          end
          url = false if url && !begin
            routes.recognize_path(url)
          rescue StandardError
            false
          end

          # Try no namespace
          unless url
            url = begin
              view.polymorphic_path(resource)
            rescue StandardError
              false
            end
            url = false if url && !begin
              routes.recognize_path(url)
            rescue StandardError
              false
            end
          end

          # So if we have a URL, this is an action we can link to
          if url
            locals[:show_path] = url.gsub('123', ':to_param')
          else
            locals[:show_action] = false
          end
        end

        if (locals[:edit_action] == true || locals[:edit_action] == :authorize_each) && !locals[:edit_path]
          # Try our namespace
          url = begin
            view.edit_polymorphic_path([*controller_namespace, resource])
          rescue StandardError
            false
          end
          url = false if url && !begin
            routes.recognize_path(url)
          rescue StandardError
            false
          end

          # Try no namespace
          unless url
            url = begin
              view.edit_polymorphic_path(resource)
            rescue StandardError
              false
            end
            url = false if url && !begin
              routes.recognize_path(url)
            rescue StandardError
              false
            end
          end

          # So if we have a URL, this is an action we can link to
          if url
            locals[:edit_path] = url.gsub('123', ':to_param')
          else
            locals[:edit_action] = false
          end
        end

        if (locals[:destroy_action] == true || locals[:destroy_action] == :authorize_each) && !locals[:destroy_path]
          # Try our namespace
          url = begin
            view.polymorphic_path([*controller_namespace, resource])
          rescue StandardError
            false
          end
          url = false if url && !begin
            routes.recognize_path(url, method: :delete)
          rescue StandardError
            false
          end

          # Try no namespace
          unless url
            url = begin
              view.polymorphic_path(resource)
            rescue StandardError
              false
            end
            url = false if url && !begin
              routes.recognize_path(url, method: :delete)
            rescue StandardError
              false
            end
          end

          # So if we have a URL, this is an action we can link to
          if url
            locals[:destroy_path] = url.gsub('123', ':to_param')
          else
            locals[:destroy_action] = false
          end
        end

        if resource.respond_to?(:archived?)
          if (locals[:unarchive_action] == true || locals[:unarchive_action] == :authorize_each) && !locals[:unarchive_path]
            # Try our namespace
            url = begin
              view.polymorphic_path([*controller_namespace, resource], action: :unarchive)
            rescue StandardError
              false
            end
            url = false if url && !begin
              routes.recognize_path(url)
            rescue StandardError
              false
            end

            # Try no namespace
            unless url
              url = begin
                view.polymorphic_path(resource, action: :unarchive)
              rescue StandardError
                false
              end
              url = false if url && !begin
                routes.recognize_path(url)
              rescue StandardError
                false
              end
            end

            # So if we have a URL, this is an action we can link to
            if url
              locals[:unarchive_path] = url.gsub('123', ':to_param')
            else
              locals[:unarchive_action] = false
            end
          end
        else
          locals[:unarchive_action] = false
        end
      end

      private

      def controller_namespace
        @controller_namespace ||= begin
          path = if attributes[:referer].present?
                   URI(attributes[:referer]).path
                 else
                   view.controller_path
                 end

          path.split('/')[0...-1].map { |path| path.downcase.to_sym if path.present? }.compact
        end
      end
    end # / Rendering
  end
end
