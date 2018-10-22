Given(/^the employee is on the (.*?) of the (.*?) employer portal$/) do |page, org|
  case page
    when "Benefits page"
      visit ("/")
      step 'I have submit the security questions'
      page.should have_selector("Zoobs")
  end
end