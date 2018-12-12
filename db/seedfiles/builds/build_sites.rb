# Creates a site

site = BenefitSponsors::Site
site_params = {"site_key"=>Settings.site.key,
 "long_name"=>Settings.site.long_name,
 "short_name"=>Settings.site.short_name,
 "byline"=>Settings.site.byline,
 "domain_name"=>Settings.site.domain_name,
 "owner_organization_attributes"=>
  {"legal_name"=>"My Org #{rand(1..1000)}",
   "profile_attributes"=>
    {"office_locations_attributes"=>
      {"0"=>
        {"is_primary"=>"true",
         "address_attributes"=>
          {"kind"=>"primary",
           "address_1"=>"123 A St",
           "address_2"=>"",
           "city"=>"Boston",
           "state"=>"MA",
           "zip"=>"01001"},
         "phone_attributes"=>
          {"kind"=>"main", "area_code"=>"510", "number"=>"0293029", "extension"=>""}}}}}}

if site.count < 1
  puts "::: Creating Site :::"
  @site = BenefitSponsors::Forms::Site.for_create site_params
  @site.save
end