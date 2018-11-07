Given(/^the employee is on the (.*?) of the (.*?) employer portal$/) do |action, org|
  case action
    when "Benefits page"
      visit benefit_sponsors.profiles_employers_employer_profile_path(employer_profile, :tab => "benefits")
      expect(page).to have_css('.heading-text', text: 'Benefits - Coverage You Offer')
      find(".interaction-click-control-benefits").trigger('click')
      wait_for_ajax(3)

      expect(page.all('tr').count - 1).to eq(count.to_i)
  end
end
