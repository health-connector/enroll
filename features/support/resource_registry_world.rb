# frozen_string_literal: true

module ResourceRegistryWorld
  def enable_feature(feature_name, args = {})
    registry_name = args[:registry_name] || EnrollRegistry
    return if feature_enabled?(feature_name)

    feature_dsl = registry_name[feature_name]
    # puts "*********** FEATURE DSL: #{feature_dsl} ***********"
    feature_dsl.feature.stub(:is_enabled).and_return(true)
  end

  def disable_feature(feature_name, args = {})
    registry_name = args[:registry_name] || EnrollRegistry
    return unless feature_enabled?(feature_name)

    feature_dsl = registry_name[feature_name]
    feature_dsl.feature.stub(:is_enabled).and_return(false)
  end

  def feature_enabled?(feature_name, args = {})
    registry_name = args[:registry_name] || EnrollRegistry
    registry_name.feature_enabled?(feature_name)
  end
end
