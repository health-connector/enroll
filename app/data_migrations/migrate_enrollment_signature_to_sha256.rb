# frozen_string_literal: true

require File.join(Rails.root, "lib/mongoid_migration_task")

class MigrateEnrollmentSignatureToSha256 < MongoidMigrationTask
  # Backfill all existing enrollment_signature values from MD5 to SHA256
  # This ensures all records use the same hash algorithm before deploying the code change
  #
  # Usage: bundle exec rails runner 'MigrateEnrollmentSignatureToSha256.new.migrate'
  # Or for production: DRYRUN=false bundle exec rails runner 'MigrateEnrollmentSignatureToSha256.new.migrate'

  def migrate
    dryrun = ENV['DRYRUN'].to_s != 'false'
    batch_size = 100
    total_count = 0
    updated_count = 0
    error_count = 0

    puts "=" * 80
    puts "MIGRATION: Backfill enrollment_signature from MD5 to SHA256"
    puts "DRY RUN: #{dryrun}"
    puts "=" * 80
    puts ""

    total_count = enrollment_signature_count

    puts "Found #{total_count} enrollments with enrollment_signature to migrate"
    puts ""

    if total_count == 0
      puts "✓ No enrollments to migrate"
      return
    end

    # Process in batches
    idx = -1
    each_enrollment_with_signature do |enrollment|
      idx += 1
      begin
        old_sig = enrollment.enrollment_signature
        new_sig = generate_sha256_signature(enrollment)

        # Only update if signature changed (i.e., it was MD5)
        if old_sig != new_sig
          enrollment.update_attribute(:enrollment_signature, new_sig) unless dryrun
          updated_count += 1

          puts "[#{idx + 1}/#{total_count}] Updated #{updated_count} enrollments (#{error_count} errors)" if (idx + 1) % batch_size == 0
        end
      rescue StandardError => e
        error_count += 1
        puts "ERROR processing enrollment #{enrollment.hbx_id}: #{e.message}"
      end
    end

    puts ""
    puts "=" * 80
    puts "MIGRATION COMPLETE"
    puts "Total enrollments processed: #{total_count}"
    puts "Total updated to SHA256: #{updated_count}"
    puts "Total errors: #{error_count}"
    puts "DRY RUN: #{dryrun}"
    puts "=" * 80
  end

  private

  def enrollment_signature_count
    result = Family.collection.aggregate(
      [
        { "$unwind" => "$households" },
        { "$unwind" => "$households.hbx_enrollments" },
        {
          "$match" => {
            "households.hbx_enrollments.enrollment_signature" => {
              "$exists" => true,
              "$nin" => [nil, ""]
            }
          }
        },
        { "$count" => "count" }
      ],
      allow_disk_use: true
    ).first

    result ? result["count"] : 0
  end

  def each_enrollment_with_signature
    families_with_signature = Family.where(
      "households.hbx_enrollments" => {
        :$elemMatch => {
          "enrollment_signature" => {
            :$exists => true,
            :$nin => [nil, ""]
          }
        }
      }
    )

    families_with_signature.no_timeout.each do |family|
      family.households.each do |household|
        household.hbx_enrollments.each do |enrollment|
          next if enrollment.enrollment_signature.blank?

          yield enrollment
        end
      end
    end
  end

  def generate_sha256_signature(enrollment)
    if enrollment.subscriber
      Digest::SHA256.hexdigest(enrollment.subscriber.applicant_id.to_s)
    elsif enrollment.subscriber.nil?
      applicant_ids = enrollment.hbx_enrollment_members.map(&:applicant_id)
      Digest::SHA256.hexdigest(applicant_ids.sort.map(&:to_s).join)
    end
  end
end
