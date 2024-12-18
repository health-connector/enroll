# frozen_string_literal: true

module IndividualMarket
  module Api
    module V1
      class SlcspController < ActionController::Base

        def plan
          request_xml = request.body.read
          parsed_request = HappyMapper.parse(request_xml)
          @plan = find_slcsp(Date.strptime(parsed_request.coverage_start, "%Y%m%d"))

          render :template => 'shared/_plan.xml.builder', :layout => false, status: :ok

        # rubocop:disable Lint/RescueException
        rescue Exception => e
          render :xml => "<errors><error>#{e.message}</error></errors>", status: :unprocessable_entity
        # rubocop:enable Lint/RescueException
        end

        private

        def find_slcsp(coverage_start)
          benefit_coverage_period = Organization
                                    .where(dba: 'DCHL')
                                    .first.hbx_profile
                                    .benefit_sponsorship.benefit_coverage_periods
                                    .detect do |bcp|
            bcp.start_on <= coverage_start && benefit_coverage_period.end_on >= coverage_start
          end

          Plan.find(benefit_coverage_period.slcsp) unless benefit_coverage_period.nil?
        end
      end
    end
  end
end