FactoryGirl.define do
  factory :employer_attestation_document do
    employer_attestation
    identifier "urn:openhbx:terms:v1:file_storage:s3:bucket:mhc-enroll-attestations-qa#843567864-8260-56-9b563488-381e4436"
    title "Document #{Forgery('basic').text(:allow_lower   => false,
                                            :allow_upper   => false,
                                            :allow_numeric => true,
                                            :allow_special => false, :exactly => 1)}"
  end
end
