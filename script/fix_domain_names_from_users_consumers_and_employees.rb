class FixDomainNames
  attr_accessor :people, :users, :record_update_failures

  def initialize(people, users)
    @people = people
    @users = users
    @record_update_failures = {
      people_consumer_roles: [],
      people_employee_roles: [],
      user_records: []
    }
  end

  def run
    modify_people if @people.count > 0
    modify_users if @users.count > 0
    print_failures
  end

  def modify_people
    @people.each do |person|
      puts("Modifying #{@people.count} person records.") unless Rails.env.test?
      if person.consumer_role.present? && person.consumer_role.bookmark_url.present?
      	person.consumer_role.update_attributes(bookmark_url: "")
        if person.consumer_role.bookmark_url.present?
          @record_update_failures[:people_consumer_roles] << person.id.to_s
        end
      end
      if person.employee_roles.present?
        person.employee_roles.each do |employee_role| 
          if employee_role.bookmark_url.present?
            employee_role.update_attributes(bookmark_url: "")
            if employee_role.bookmark_url.present?
              @record_update_failures[:people_employee_roles] << person.id.to_s
            end
          end
        end
      end
    end
  end

  def modify_users
    @users.each do |user|
      puts("Modifying #{@users.count} user records.") unless Rails.env.test?
      user.update_attributes(last_portal_visited: "") if user.last_portal_visited.present?
      @record_update_failures[:user_records] << user.id.to_s if user.last_portal_visited.present?
    end
  end

  def print_failures
    unless Rails.env.test?
      puts("No people records modified.") if @people.blank?
      puts("No user records modified.") if @users.blank?
    end
    @record_update_failures.each do |key, values|
      if values.length > 0
        unless Rails.env.test?
          puts("For " + key.to_s + ", the following records failed to update: " + values.to_s)
        end
      else
        unless Rails.env.test?
          puts("No update failures for " + key.to_s)
        end
      end
    end
  end
end

# Related to ticket 40226
people = Person.all.to_a
users = User.all.to_a
fix_domain_names = FixDomainNames.new(people, users)
fix_domain_names.run