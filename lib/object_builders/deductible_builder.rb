# frozen_string_literal: true

class DeductibleBuilder
  INVALID_PLAN_IDS = ["88806MA0020005", "88806MA0040005", "88806MA0020051",
                      "18076MA0010001", "80538MA0020001", "80538MA0020002", "11821MA0020001", "11821MA0040001"].freeze # These plan ids are suppressed and we dont save these while importing.
  LOG_PATH = "#{Rails.root}/log/rake_xml_import_products_#{Time.now.to_s.delete(' ', '')}.log"

  def initialize(qhp_hash)
    @log_path = LOG_PATH
    @qhp_hash = qhp_hash
    @qhp_array = []
    FileUtils.mkdir_p(File.dirname(@log_path)) unless File.directory?(File.dirname(@log_path))
    @logger = Logger.new(@log_path)
  end

  def add(qhp_hash)
    @qhp_array += qhp_hash[:packages_list][:packages]
  end

  def run
    @xml_plan_counter = 0
    iterate_plans
    show_qhp_stats unless Rails.env.test?
  end

  def iterate_plans
    @qhp_array.each do |products|
      @products = products
      @xml_plan_counter += products[:plans_list][:plans].size
      products[:plans_list][:plans].each do |product|
        @product = product
        build_qhp_params
      end
    end
  end

  def build_qhp_params
    build_qhp
    build_benefits
    build_cost_share_variances_list
    validate_and_persist_qhp
  end

  def show_qhp_stats
    puts "*" * 80
    puts "Total Number of Products imported from xml: #{@xml_plan_counter}."
    puts "Check the log file #{@log_path}"
    puts "*" * 80
    @logger.info "\nTotal Number of Plans imported from xml: #{@xml_plan_counter}.\n"
  end

  def validate_and_persist_qhp
    unless INVALID_PLAN_IDS.include?(@qhp.standard_component_id.strip)
      associate_product_with_qhp
      @qhp.save!
    end
    @logger.info "\nSaved Plan: #{@qhp.plan_marketing_name}, hios product id: #{@qhp.standard_component_id} \n"
  rescue StandardError => e
    error_message = "\n Failed to create plan: #{@qhp.plan_marketing_name}, \n hios product id: #{@qhp.standard_component_id}"
    error_message += " \n Exception Message: #{e.message} \n\n Errors: #{@qhp.errors.full_messages} \n\n Backtrace: #{e.backtrace.join("\n")}\n ******************** \n"
    @logger.error error_message
  end

  def associate_product_with_qhp
    effective_date = @qhp.plan_effective_date.to_date
    @qhp.plan_effective_date = effective_date.beginning_of_year
    @qhp.plan_expiration_date = effective_date.end_of_year
  end

  def is_health_product?
    @qhp.dental_plan_only_ind.casecmp('no').zero?
  end

  def retrieve_metal_level
    is_health_product? ? @qhp.metal_level.downcase : 'dental'
  end

  def parse_market
    @qhp.market_coverage = @qhp.market_coverage.downcase.include?('shop') ? 'shop' : 'individual'
  end

  def build_qhp
    @qhp = Products::Qhp.where(active_year: qhp_params[:active_year], standard_component_id: qhp_params[:standard_component_id]).first
    if @qhp.present?
      @qhp.attributes = qhp_params
      @qhp.qhp_benefits = []
      @qhp.qhp_cost_share_variances = []
    else
      @qhp = Products::Qhp.new(qhp_params)
    end
  end

  def build_benefits
    benefits_params.each { |benefit| @qhp.qhp_benefits.build(benefit) }
  end

  def build_cost_share_variances_list
    cost_share_variance_list_params.each do |csvp|
      @csvp = csvp
      next if hios_plan_and_variant_id.split("-").last == '00'

      update_hsa_eligibility
      build_cost_share_variance
    end
  end

  def update_hsa_eligibility
    @qhp.hsa_eligibility = hsa_params[:hsa_eligibility] if hios_plan_and_variant_id.split('-').last == '01'
  end

  def build_cost_share_variance
    build_sbc_params
    build_moops
    build_service_visits
    build_deductible
  end

  def build_deductible
    plan_deductible_list_params.each do |plan_deductible|
      @csv.qhp_deductibles.build(plan_deductible)
    end
  end

  def plan_deductible_list_params
    @csvp[:plan_deductible_list_attributes][:plan_deductible_attributes]
  end

  def build_service_visits
    service_visits_params.each do |svp|
      @csv.qhp_service_visits.build(svp)
    end
  end

  def build_moops
    maximum_out_of_pockets_params.each do |moop|
      @csv.qhp_maximum_out_of_pockets.build(moop)
    end
  end

  def build_sbc_params
    @csv = if sbc_params
             @qhp.qhp_cost_share_variances.build(cost_share_variance_attributes.merge(sbc_params))
           else
             @qhp.qhp_cost_share_variances.build(cost_share_variance_attributes)
           end
  end

  def hios_plan_and_variant_id
    cost_share_variance_attributes[:hios_plan_and_variant_id]
  end

  def hsa_params
    @csvp[:hsa_attributes]
  end

  def service_visits_params
    @csvp[:service_visits_attributes]
  end

  def deductible_params
    @csvp[:deductible_attributes]
  end

  def maximum_out_of_pockets_params
    @csvp[:maximum_out_of_pockets_attributes]
  end

  def sbc_params
    @csvp[:sbc_attributes]
  end

  def cost_share_variance_attributes
    @csvp[:cost_share_variance_attributes]
  end

  def cost_share_variance_list_params
    @product[:cost_share_variance_list_attributes]
  end

  def benefits_params
    @products[:benefits_list][:benefits]
  end

  def qhp_params
    header_params.merge(product_attribute_params)
  end

  def header_params
    @products[:header]
  end

  def product_attribute_params
    assign_active_year_to_qhp
    @product[:plan_attributes]
  end

  def assign_active_year_to_qhp
    @product[:plan_attributes][:active_year] = @product[:plan_attributes][:plan_effective_date][-4..-1].to_i
  end

end