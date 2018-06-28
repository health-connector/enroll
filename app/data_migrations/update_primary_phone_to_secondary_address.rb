require File.join(Rails.root, "lib/mongoid_migration_task")
class UpdatePrimaryPhoneToSecondaryAddress< MongoidMigrationTask
  def migrate
    organization = Organization.where(
       :"office_locations" => {
         :"$elemMatch" => {
          :"is_primary"=> false,
          :"phone"=> nil
         }
       }
       )
    organization.each do |org|
      primary_office_location_phone = org.office_locations.where(:is_primary => true).first.phone
      secondary_office_locations = org.office_locations.where(:is_primary => false,:"phone"=> nil)
      secondary_office_locations.each do |secondary_office_location|
        secondary_office_location.phone = primary_office_location_phone
        secondary_office_location.save! 
      end
    end
  end
end
