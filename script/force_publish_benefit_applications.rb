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

def select_benefit_application(benefit_sponsorship)
  if benefit_sponsorship.renewing_submitted_benefit_application.present?
    return benefit_sponsorship.renewing_submitted_benefit_application
  else
    return benefit_sponsorship.renewal_benefit_application
  end
end

start_on_date = window.end.next_month.beginning_of_month

benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where("benefit_applications.effective_period.min" => start_on_date.to_time.utc.beginning_of_day)

benefit_applications = []
benefit_sponsorships.each{|bs| benefit_applications << select_benefit_application(bs)}

benefit_applications.each do |ba|
  begin
    ba.simulate_provisional_renewal! if may_simulate_provisional_renewal?
  rescue Exception=>e
    puts "Could not force publish #{ba.benefit_sponsorship.organization.legal_name} because of #{e.inspect}"
    next
  end
end
