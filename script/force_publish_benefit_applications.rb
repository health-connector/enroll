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

start_on_date = window.end.next_month.beginning_of_month

benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.where("benefit_applications.effective_period.min" => start_on_date.to_time.utc.beginning_of_day)

benefit_applications = []
benefit_sponsorships.each{|bs| benefit_applications << bs.benefit_applications.detect{|ba| ba.effective_period.min == start_on_date}}

benefit_applications.each do |ba|
  begin
    ba.simulate_provisional_renewal!
  rescue Exception=>e
    puts "Could not force publish #{ba.benefit_sponsorship.organization.legal_name} because of #{e.inspect}"
    next
  end
end
