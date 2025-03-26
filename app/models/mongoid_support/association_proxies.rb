module MongoidSupport
  module AssociationProxies
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def associated_with_one(attr_name, key_name, kls_name)
        kls = kls_name.constantize

        define_method(attr_name) do
          instance_variable_name = :"@__proxy_value_for_#{attr_name}"
          return instance_variable_get(instance_variable_name) if instance_variable_defined?(instance_variable_name)
          return nil if self.send(key_name).blank?
          instance_variable_set(instance_variable_name, kls.find(self.send(key_name)))
        end

        define_method("#{attr_name}=") do |val|
          instance_variable_set(:"@__proxy_value_for_#{attr_name}", val)
          if val.nil?
            self.send("#{key_name}=", nil)
          else
            self.send("#{key_name}=", val.id)
          end
          val
        end

        define_method("__association_reload_on_#{attr_name}") do
          instance_variable_set(:"@__proxy_value_for_#{attr_name}", nil)
        end
      end
    end
  end
end
