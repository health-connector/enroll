# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

class AddContributionModelsToProductPackage < MongoidMigrationTask

  def migrate
    year = ENV['year']&.to_i || TimeKeeper.date_of_record.year
    date = Date.new(year,1,1)
    site = BenefitSponsors::Site.by_site_key(Settings.site.key).first

    title_percentage_pair = {
      zero_percent_sponsor_fixed_percent_contribution_model: 0.0,
      fifty_percent_sponsor_fixed_percent_contribution_model: 0.5
    }

    benefit_market = site.benefit_markets.where(kind: :aca_shop).first
    benefit_market_catalog = benefit_market.benefit_market_catalogs.by_application_date(date).first

    raise "Unable to find benefit market catalog for the #{date.to_date}" unless benefit_market_catalog

    benefit_market_catalog.product_packages.each do |product_package|
      next unless product_package.product_kind == :health

      product_package.contribution_models = title_percentage_pair.collect do |title, pct|
        contribution_model = create_contribution_model(product_package.contribution_model)
        update_title_and_contribution_percentages(contribution_model, title, pct)
      end
      product_package.save
    end

    benefit_market_catalog.save!
  end

  def create_contribution_model(contribution_model)
    new_contribution_model = contribution_model.class.new(contribution_model.attributes.except(:_id, :contribution_units, :member_relationships))
    new_contribution_model.contribution_units = contribution_model.contribution_units.collect{ |contribution_unit| contribution_unit.class.new(contribution_unit.attributes.except(:_id)) }
    new_contribution_model.member_relationships = contribution_model.member_relationships.collect{ |mr| mr.class.new(mr.attributes.except(:_id)) }
    new_contribution_model
  end

  def update_title_and_contribution_percentages(contribution_model, title, pct)
    contribution_model.title = title.to_s.humanize.titleize
    contribution_model.key = title

    contribution_model.contribution_units.each do |contribution_unit|
      pct_for_family = title.match?(/zero/) ? 0.0 : 0.33
      if ['employee', 'employee_only'].include?(contribution_unit.name)
        contribution_unit.default_contribution_factor = pct
        contribution_unit.minimum_contribution_factor = pct
      else
        contribution_unit.default_contribution_factor = pct_for_family
        contribution_unit.minimum_contribution_factor = pct_for_family
      end
    end
    contribution_model
  end
end
