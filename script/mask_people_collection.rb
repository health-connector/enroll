# frozen_string_literal: true

# bundle exec rails r script/mask_people_collection.rb -e production

require 'ffaker'
require 'set'

def generate_unique_ssn(used_ssns)
  loop do
    new_ssn = FFaker::SSN.ssn
    unless used_ssns.include?(new_ssn)
      used_ssns.add(new_ssn)
      return new_ssn
    end
  end
end

def process_batch(batch, used_names, used_ssns, updates)
  batch.each do |doc|
    # Generate new, unique first and last names
    new_first_name = FFaker::Name.first_name
    new_last_name = FFaker::Name.last_name
    unique_name = "#{new_first_name} #{new_last_name}"

    while used_names.include?(unique_name)
      new_first_name = FFaker::Name.first_name
      new_last_name = FFaker::Name.last_name
      unique_name = "#{new_first_name} #{new_last_name}"
    end
    used_names.add(unique_name)

    # Generate a new, unique SSN
    new_ssn = generate_unique_ssn(used_ssns)

    # Set middle_name to nil and generate full_name
    middle_name = nil
    full_name = "#{new_first_name} #{middle_name} #{new_last_name}".squeeze(' ').strip

    # Prepare the update query
    updates << {
      update_one: {
        filter: { "_id" => doc["_id"] },
        update: {
          "$set" => {
            "first_name" => new_first_name,
            "middle_name" => middle_name,
            "last_name" => new_last_name,
            "ssn" => new_ssn,
            "full_name" => full_name
          }
        }
      }
    }
  end
end

def update_people_collection
  used_names = Set.new
  used_ssns = Set.new
  batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
  people_collection = Person.collection
  updates = []

  puts "Starting the update process..."
  processed_count = 0
  total_count = people_collection.count_documents({})

  # Fetch records in batches
  people_collection.find({}, { projection: { _id: 1, first_name: 1, last_name: 1, middle_name: 1 } }).each_slice(batch_size) do |batch|
    process_batch(batch, used_names, used_ssns, updates)

    # Write updates in bulk to MongoDB
    begin
      people_collection.bulk_write(updates) unless updates.empty?
      processed_count += batch.size
      puts "Processed #{processed_count} / #{total_count} records..."
    rescue StandardError => e
      puts "Error while processing batch: #{e.message}"
    ensure
      updates.clear
    end
  end

  puts "Update process completed successfully! Total records processed: #{processed_count}"
end

update_people_collection
