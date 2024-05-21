# frozen_string_literal: true

date = Date.today

if date.day > 15
  window_start = Date.new(date.year,date.month,16)
  window_end = Date.new(date.next_month.year,date.next_month.month,15)
  window = (window_start..window_end)
elsif date.day <= 15
  window_start = Date.new((date - 1.month).year,(date - 1.month).month,16)
  window_end = Date.new(date.year,date.month,15)
  window = (window_start..window_end)
end

start_on_date = window.end.next_month.beginning_of_month.to_time.utc.beginning_of_day

product_cache = {}

BenefitMarkets::Products::Product.all.each do |product|
  product_cache[product.id] = product
end

def benefit_applications_in_aasm_state(_aasm_states, start_on_date)
  BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where(
    :benefit_applications =>
      { :$elemMatch =>
        {
          :"benefit_application_items.0.effective_period.min" => start_on_date,
          :aasm_state.in => [
                              :enrollment_open,
                              :enrollment_closed,
                              :enrollment_eligible,
                              :enrollment_extended,
                              :active
                            ]
        }}
  )
end

def matching_plan_details(enrollment, other_hbx_enrollment, product_cache)
  return false if other_hbx_enrollment.product_id.blank?

  new_plan = product_cache[enrollment.product_id]
  old_plan = product_cache[other_hbx_enrollment.product_id]
  (old_plan.issuer_profile_id == new_plan.issuer_profile_id) &&
    (old_plan.active_year == new_plan.active_year - 1)
end

def initial_or_renewal(enrollment, product_cache, predecessor_id)
  return "initial" if predecessor_id.blank?

  renewal_enrollments = fetch_renewal_enrollments(enrollment, predecessor_id)
  renewal_enrollments_no_cancels_waives = filter_enrollments_by_status(renewal_enrollments)
  renewal_enrollments_no_terms = filter_terminated_enrollments(renewal_enrollments_no_cancels_waives, enrollment)

  if renewal_enrollments_no_terms.any? { |ren| matching_plan_details(enrollment, ren, product_cache) }
    "renewal"
  else
    "initial"
  end
end

def fetch_renewal_enrollments(enrollment, predecessor_id)
  enrollment.family.households.flat_map(&:hbx_enrollments).select { |hbx_enrollment| hbx_enrollment.sponsored_benefit_package_id == predecessor_id }
end

def filter_enrollments_by_status(enrollments)
  reject_statuses = HbxEnrollment::CANCELED_STATUSES + HbxEnrollment::WAIVED_STATUSES + %w[unverified void]
  enrollments.reject { |ren| reject_statuses.include?(ren.aasm_state.to_s) }
end

def filter_terminated_enrollments(enrollments, enrollment)
  enrollments.reject do |ren|
    %w[coverage_terminated coverage_termination_pending].include?(ren.aasm_state.to_s) &&
      ren.terminated_on.present? &&
      ren.terminated_on < (enrollment.effective_on - 1.day)
  end
end

renewed_sponsorships = find_renewed_sponsorships(start_on_date)

initial_file = File.open("policies_to_pull_ies.txt","w")
renewal_file = File.open("policies_to_pull_renewals.txt","w")

renewed_sponsorships.each do |bs|
  selected_application = bs.benefit_applications.detect do |ba|
    !ba.predecessor_id.blank? &&
      (ba.start_on == start_on_date) &&
      [:enrollment_open,:enrollment_closed,:enrollment_eligible,:active].include?(ba.aasm_state)
  end

  next if selected_application.blank?

  benefit_packages = selected_application.benefit_packages

  enrollment_ids = []

  benefit_packages.each do |benefit_package|
    employer_enrollment_query = ::Queries::NamedEnrollmentQueries.find_simulated_renewal_enrollments(benefit_package.sponsored_benefits, start_on_date)
    employer_enrollment_query.each{|id| enrollment_ids << id}
  end

  enrollment_ids.each do |enrollment_hbx_id|
    enrollment = HbxEnrollment.by_hbx_id(enrollment_hbx_id).first
    puts "#{enrollment.hbx_id} has no plan" if enrollment.product.blank?
    case initial_or_renewal(enrollment,product_cache,selected_application.benefit_packages.first.predecessor_id)
    when 'initial'
      initial_file.puts(enrollment_hbx_id)
    when 'renewal'
      renewal_file.puts(enrollment_hbx_id)
    end
  end
end

initial_file.close
renewal_file.close

