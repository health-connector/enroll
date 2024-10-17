# frozen_string_literal: true

module BenefitSponsors
  module EmployerEvents
    class Renderer
      XML_NS = "http://openhbx.org/api/terms/1.0"

      attr_accessor :employer_event, :timestamp

      def initialize(e_event)
        @employer_event = e_event
        @timestamp = e_event.event_time
      end

      def carrier_plan_years(carrier)
        doc = Nokogiri::XML(employer_event.resource_body)
        doc.xpath("//cv:elected_plans/cv:elected_plan/cv:carrier/cv:id/cv:id[text() = '#{carrier.hbx_carrier_id}']/../../../../../../..", {:cv => XML_NS})
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def has_current_or_future_plan_year?(carrier)
        found_plan_year = false
        carrier_plan_years(carrier).each do |node|
          node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
            begin
              date_value = Date.strptime(date_node.content.strip, "%Y%m%d")
            rescue StandardError => e
              puts "Error parsing start date: #{e.message}" unless Rails.env.test?
            end
            next unless date_value

            found_plan_year = true if date_value >= Date.today
          end
          node.xpath("cv:plan_year_end", {:cv => XML_NS}).each do |date_node|
            begin
              date_value = Date.strptime(date_node.content.strip, "%Y%m%d")
            rescue StandardError => e
              puts "Error parsing end date: #{e.message}" unless Rails.env.test?
            end
            next unless date_value

            found_plan_year = true if date_value >= Date.today
          end
        end
        found_plan_year
      end

      def finding_all_plan_years
        doc = Nokogiri::XML(employer_event.resource_body)
        doc.xpath("//cv:plan_year", {:cv => XML_NS})
      end

      def finding_sorted_plan_years(all_plan_years)
        all_plan_years.sort_by do |node|
          Date.strptime(node.xpath("cv:plan_year_start", {:cv => XML_NS}).first.content.strip,"%Y%m%d")
        rescue StandardError
          puts "Could not find sorted plan year start date" unless Rails.env.test?
        end
      end

      def should_send_retroactive_term_or_cancel?(carrier)
        events = BenefitSponsors::EmployerEvents::EventNames::TERMINATION_EVENT + [BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT]
        return false unless events.include?(employer_event.event_name)

        all_plan_years = finding_all_plan_years
        return false if all_plan_years.empty?

        sorted_plan_years = finding_sorted_plan_years(all_plan_years)
        last_plan_year = sorted_plan_years.last
        if last_plan_year.present? && last_plan_year.xpath("//cv:elected_plans/cv:elected_plan/cv:carrier/cv:id/cv:id[text() = '#{carrier.hbx_carrier_id}']", {:cv => XML_NS}).any?
          start_date = begin
            Date.strptime(last_plan_year.xpath("cv:plan_year_start", {:cv => XML_NS}).first.content.strip,"%Y%m%d")
          rescue StandardError
            puts "Could not find retroactive plan year start date" unless Rails.env.test?
          end
          end_date = begin
            Date.strptime(last_plan_year.xpath("cv:plan_year_end", {:cv => XML_NS}).first.content.strip,"%Y%m%d")
          rescue StandardError
            puts "Could not find retroactive plan year end date" unless Rails.env.test?
          end
          return false if start_date.blank? || end_date.blank?

          if employer_event.event_name == BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT
            start_date == end_date || Date.today >= end_date
          else
            start_date != end_date && end_date > Date.today - 1.year
          end
        else
          false
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def renewal_and_no_future_plan_year?(carrier)
        return false if employer_event.event_name != BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT

        found_future_plan_year = false
        carrier_plan_years(carrier).each do |node|
          end_date = begin
            raw_end_date = node.xpath("cv:plan_year_end", {:cv => XML_NS}).first.content.strip
            Date.strptime(raw_end_date, "%Y%m%d")
          rescue StandardError => e
            puts "Could not find renewal and no_future plan year end date: #{e.message}" unless Rails.env.test?
            nil
          end

          node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
            date_value = begin
              raw_start_date = date_node.content.strip
              Date.strptime(raw_start_date, "%Y%m%d")
            rescue StandardError => e
              puts "Could not find renewal and no_future plan year start date: #{e.message}" unless Rails.env.test?
              nil
            end
            next unless date_value

            found_future_plan_year = true if date_value > Date.today && date_value != end_date
          end
        end
        !found_future_plan_year
      end

      def find_latest_carrier_plan_year_in_event(carrier)
        date_sets = carrier_plan_years(carrier).map do |node|
          start_date_node = node.at_xpath("cv:plan_year_start", {:cv => XML_NS})
          end_date_node = node.at_xpath("cv:plan_year_end", {:cv => XML_NS})
          start_date_value = begin
            Date.strptime(start_date_node.content.strip, "%Y%m%d")
          rescue StandardError
            puts "Could not find latest_carrier plan year start date" unless Rails.env.test?
          end
          end_date_value = begin
            Date.strptime(end_date_node.content.strip, "%Y%m%d")
          rescue StandardError
            puts "Could not find latest_carrier plan year end date" unless Rails.env.test?
          end
          start_date_value && end_date_value ? [start_date_value, end_date_value] : nil
        end.compact
        date_sets.max_by(&:first)
      end

      def qualifies_to_update_event_name?(carrier, employer_event)
        events = [BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT, BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME]
        # return true if employer_event.event_name.in?(events) && carrier.uses_issuer_centric_sponsor_cycles
        return true if employer_event.event_name.in?(events) && [20_001, 20_004].include?(carrier.hbx_carrier_id)
      end

      def update_event_name(carrier, employer_event)
        return employer_event.event_name unless qualifies_to_update_event_name?(carrier, employer_event)

        employer_profile = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(hbx_id: employer_event.employer_profile_id).first
        raise ::BenefitSponsors::EmployerEvents::Errors::EmployerEventEmployerNotFound, "No employer found for: #{employer_event.employer_profile_id}, Employer Event: #{employer_event.id}" if employer_profile.nil?

        most_recent_plan_year_dates = find_latest_carrier_plan_year_in_event(carrier)
        raise ::BenefitSponsors::EmployerEvents::Errors::NoCarrierPlanYearsInEvent, "No plan years found in event for: #{carrier.id}, Employer Event: #{employer_event.id}" if most_recent_plan_year_dates.nil?

        start_date, end_date = most_recent_plan_year_dates
        plan_year = find_employer_plan_year_by_date(employer_profile, start_date, end_date)
        if has_previous_plan_year_for_carrier?(employer_profile, plan_year, carrier)
          BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT
        else
          BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME
        end
      end

      def has_previous_plan_year_for_carrier?(employer_profile, plan_year, carrier)
        previous_plan_years = employer_profile.benefit_applications.where(:'benefit_application_items.effective_period.max' => (plan_year.start_on - 1.day))
        return false if previous_plan_years.empty?

        non_canceled_plan_years = previous_plan_years.reject do |py|
          py.start_on == py.end_on
        end
        return false if non_canceled_plan_years.empty?

        last_matching_plan_year = non_canceled_plan_years.max_by(&:start_on)
        return false if last_matching_plan_year.blank?

        has_last_matching_plan_year_for_carrier?(last_matching_plan_year, carrier) && plan_year_is_at_least_one_year_long?(last_matching_plan_year)
      end

      def has_last_matching_plan_year_for_carrier?(last_matching_plan_year, carrier)
        last_matching_plan_year&.benefit_packages&.flat_map(&:sponsored_benefits)&.flat_map(&:reference_product)&.flat_map(&:issuer_profile)&.flat_map(&:hbx_carrier_id)&.include?(carrier.hbx_carrier_id)
      end

      def plan_year_is_at_least_one_year_long?(plan_year)
        return false if plan_year.end_on.blank?

        plan_year.end_on >= (plan_year.start_on + 1.year - 1.day)
      end

      def find_employer_plan_year_by_date(employer_profile, start_date, end_date)
        found_py = employer_profile.benefit_applications.where(:'benefit_application_items.effective_period.min' => start_date, :'benefit_application_items.effective_period.max' => end_date).first
        ::BenefitSponsors::EmployerEvents::Errors::EmployerPlanYearNotFound.new("No plan year found for: #{employer_event.employer_profile_id}, Start: #{start_date}, End: #{end_date}") if found_py.nil?
        found_py
      end

      def drop_and_has_future_plan_year?(carrier)
        return false if employer_event.event_name != BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT

        found_future_plan_year = false
        carrier_plan_years(carrier).each do |node|
          node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
            date_value = begin
              Date.strptime(date_node.content.strip, "%Y%m%d")
            rescue StandardError
              puts "Could not find drop_and_has_future plan year start date" unless Rails.env.test?
            end
            next unless date_value

            found_future_plan_year = true if date_value > Date.today
          end
        end
        found_future_plan_year
      end

      def render_for(carrier, out)
        return :event_not_whitelisted unless event_whitelisted?(employer_event)
        return :no_carrier_plan_years unless carrier_has_plan_years?(carrier)
        return :invalid_plan_year unless valid_plan_year?(carrier)
        return :drop_and_has_future_plan_year if drop_and_has_future_plan_year?(carrier)
        return :renewal_and_no_future_plan_year if renewal_and_no_future_plan_year?(carrier)

        employer_profile = fetch_employer_profile(employer_event)
        doc = Nokogiri::XML(employer_event.resource_body)
        filter_xml(doc, carrier)
        event_header = build_event_header(carrier, employer_event, employer_profile)
        event_trailer = build_event_trailer
        out << event_header
        out << doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_DECLARATION, indent: 2).gsub(/^/, '  ')
        out << event_trailer
        true
      end

      private

      def event_whitelisted?(employer_event)
        ::BenefitSponsors::EmployerEvents::EventNames::EVENT_WHITELIST.include?(employer_event.event_name)
      end

      def carrier_has_plan_years?(carrier)
        carrier_plan_years(carrier).any?
      end

      def valid_plan_year?(carrier)
        has_current_or_future_plan_year?(carrier) || should_send_retroactive_term_or_cancel?(carrier)
      end

      def fetch_employer_profile(employer_event)
        BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(hbx_id: employer_event.employer_profile_id).first
      end

      def filter_xml(doc, carrier)
        doc.xpath("//cv:elected_plans/cv:elected_plan", { cv: XML_NS }).each do |node|
          carrier_id = node.at_xpath("cv:carrier/cv:id/cv:id", { cv: XML_NS }).content
          node.remove if carrier_id != carrier.hbx_carrier_id.to_s
        end
        doc.xpath("//cv:employer_census_families", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:benefit_group/cv:reference_plan", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:benefit_group/cv:elected_plans[not(cv:elected_plan)]", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:broker_agency_profile[not(cv:brokers)]", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:employer_profile/cv:brokers[not(cv:broker_account)]", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:benefit_group[not(cv:elected_plans)]", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:plan_year/cv:benefit_groups[not(cv:benefit_group)]", { cv: XML_NS }).each(&:remove)
        doc.xpath("//cv:plan_year[not(cv:benefit_groups)]", { cv: XML_NS }).each(&:remove)
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      def build_event_header(carrier, employer_event, employer_profile)
        <<-XMLHEADER
          <employer_event>
            <event_name>urn:openhbx:events:v1:employer##{update_event_name(carrier, employer_event)}</event_name>
            <resource_instance_uri>
              <id>urn:openhbx:resource:organization:id##{employer_profile&.organization&.hbx_id}</id>
            </resource_instance_uri>
            <body>
        XMLHEADER
      end

      def build_event_trailer
        <<-XMLTRAILER
            </body>
          </employer_event>
        XMLTRAILER
      end
    end
  end
end
