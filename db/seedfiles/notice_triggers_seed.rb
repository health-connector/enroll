puts "*"*80
puts "::: Cleaning ApplicationEventKinds :::"
ApplicationEventKind.delete_all

shop_notice_triggers = [
  
{
    hbx_id: 'SHOP0',
    title: 'Welcome Notice to Employer',
    description: 'ER creates an account in Health',
    resource_name: 'employer',
    event_name: 'application_created',
    notice_triggers: [
      {
        name: 'Welcome Notice sent to Employer',
        notice_template: 'notices/shop_employer_notices/0_welcome_notice_employer',
        notice_builder: 'ShopEmployerNotices::WelcomeEmployerNotice',
        mpi_indicator: 'MPI_SHOP0',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'SHOP1A',
    title: 'Initial Employer SHOP Application Approval',
    description: 'ER application requirements met SHOP participation approved',
    resource_name: 'employer',
    event_name: 'application_accepted',
    notice_triggers: [
      {
        name: 'Employer notice trigger',
        notice_template: 'notices/shop_employer_notices/1a_application_approval',
        notice_builder: 'ShopEmployerNotices::EmployerRenewalNotice',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP1B',
    title: 'Request for Clarifying Documentation',
    description: 'User has 30 calendar days to respond to this notice from the notice date',
    resource_name: 'employer',
    event_name: 'application_declined',
    notice_triggers: [
      {
        name: 'Employer notice trigger',
        notice_template: 'notices/shop_employer_notices/1b_request_documents',
        notice_builder: 'ShopEmployerNotices::EmployerRenewalNotice',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP1C',
    title: 'Approval of Employer SHOP Application after Request for Clarifying Documentation',
    description: 'ER application requirements met SHOP participation approved',
    resource_name: 'employer',
    event_name: 'benefit_coverage_initial_binder_paid',
    notice_triggers: [
      {
        name: 'Employer notice trigger',
        notice_template: 'notices/shop_employer_notices/1c_application_approval',
        notice_builder: 'ShopEmployerNotices::EmployerRenewalNotice',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP2',
    title: 'Employer Approval Notice',
    description: 'Application to Offer Group Health Coverage in DC Health Link',
    resource_name: 'employer',
    event_name: 'initial_employer_approval',
    notice_triggers: [
      {
        name: 'Initial Employer SHOP Approval Notice',
        notice_template: 'notices/shop_employer_notices/2_initial_employer_approval_notice',
        notice_builder: 'ShopEmployerNotices::InitialEmployerEligibilityNotice',
        mpi_indicator: 'MPI_SHOP2A',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP2B',
    title: 'Employer Denial Notice',
    description: 'Application to Offer Group Health Coverage in DC Health Link',
    resource_name: 'employer',
    event_name: 'initial_employer_denial',
    notice_triggers: [
      {
        name: 'Denial of Initial Employer Application/Request for Clarifying Documentation',
        notice_template: 'notices/shop_employer_notices/2_initial_employer_denial_notice',
        notice_builder: 'ShopEmployerNotices::InitialEmployerDenialNotice',
        mpi_indicator: 'MPI_SHOP2B',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP3A',
    title: 'Plan Offerings Finalized',
    description: 'Application to Offer Group Health Coverage in DC Health Link when an Employer publishes PlanYear',
    resource_name: 'employer',
    event_name: 'planyear_renewal_3a',
    notice_triggers: [
      {
        name: 'PlanYear Renewal',
        notice_template: 'notices/shop_employer_notices/3a_employer_plan_year_renewal',
        notice_builder: 'ShopEmployerNotices::RenewalEmployerEligibilityNotice',
        mpi_indicator: 'MPI_SHOPRA',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP3B',
    title: 'Plan Offerings Finalized',
    description: 'Application to Offer Group Health Coverage in DC Health Link when an Employer PlanYear is force published',
    resource_name: 'employer',
    event_name: 'planyear_renewal_3b',
    notice_triggers: [
      {
        name: 'PlanYear Renewal Auto-Published',
        notice_template: 'notices/shop_employer_notices/3b_employer_plan_year_renewal',
        notice_builder: 'ShopEmployerNotices::RenewalEmployerEligibilityNotice',
        mpi_indicator: 'MPI_SHOPRB',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'SHOP5',
    title: 'Group Renewal Available',
    description: 'Notice will be sent to the Renewal Groups three months prior to their plan year renewing',
    resource_name: 'employer',
    event_name: 'group_renewal_5',
    notice_triggers: [
      {
        name: 'Group Renewal Notice',
        notice_template: 'notices/shop_employer_notices/5_employer_renewal_notice',
        notice_builder: 'ShopEmployerNotices::EmployerRenewalNotice',
        mpi_indicator: 'MPI_SHOP5',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'SHOP6',
    title: 'Welcome to DC Health Link, Group Renewal Available',
    description: 'Renewing Your Health Insurance Coverage for Your Small Business on November 1, 2016',
    resource_name: 'employer',
    event_name: 'conversion_group_renewal',
    notice_triggers: [
      {
        name: 'Conversion, Group Renewal Available',
        notice_template: 'notices/shop_employer_notices/6_conversion_group_renewal_notice',
        notice_builder: 'ShopEmployerNotices::EmployerRenewalNotice',
        mpi_indicator: 'MPI_SHOP6',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP6',
    title: 'Action Needed – Add all Eligible Employees to your Roster',
    description: 'This notice goes to all the employers with zero employees on roster when published',
    resource_name: 'employer',
    event_name: 'zero_employees_on_roster',
    notice_triggers: [
      {
        name: 'Zero Employees on Rotser',
        notice_template: 'notices/shop_employer_notices/notice_for_employers_with_zero_employees_on_roster',
        notice_builder: 'ShopEmployerNotices::ZeroEmployeesOnRoster',
        mpi_indicator: 'MPI_SHOP6',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP8A',
    title: 'Your Health Plan Open Enrollment Period has Begun',
    description: 'All the employees that are active in coverage and have an auto-renewal plan option available.',
    resource_name: 'employee_role',
    event_name: 'employee_open_enrollment_auto_renewal',
    notice_triggers: [
      {
        name: 'Renewal Open Enrollment available for Employee',
        notice_template: 'notices/shop_employee_notices/8a_renewal_open_enrollment_notice_for_employee',
        notice_builder: 'ShopEmployeeNotices::OpenEnrollmentNoticeForAutoRenewal',
        mpi_indicator: 'MPI_SHOP8A',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employee"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP8B',
    title: 'Your Health Plan Open Enrollment Period has Begun',
    description: 'All employees that enrolled the previous year and do not have an auto-renewal plan option available.',
    resource_name: 'employee_role',
    event_name: 'employee_open_enrollment_no_auto_renewal',
    notice_triggers: [
      {
        name: 'Renewal Open Enrollment available for Employee',
        notice_template: 'notices/shop_employee_notices/8b_renewal_open_enrollment_notice_for_employee',
        notice_builder: 'ShopEmployeeNotices::OpenEnrollmentNoticeForNoRenewal',
        mpi_indicator: 'MPI_SHOP8B',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employee"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP8C',
    title: 'Your Health Plan Open Enrollment Period has Begun',
    description: 'All employees that are not currently enrolled in a plan',
    resource_name: 'employee_role',
    event_name: 'employee_open_enrollment_unenrolled',
    notice_triggers: [
      {
        name: 'Renewal Open Enrollment available for Employee',
        notice_template: 'notices/shop_employee_notices/8c_renewal_open_enrollment_notice_for_unenrolled_employee',
        notice_builder: 'ShopEmployeeNotices::OpenEnrollmentNoticeForUnenrolled',
        mpi_indicator: 'MPI_SHOP8C',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employee"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP16',
    title: 'Application to Offer Group Health Coverage in DC Health Link',
    description: 'When Employer application meets minimum participation and non-owner requirements',
    resource_name: 'employer',
    event_name: 'initial_eligibile_employer_open_enrollment_begins',
    notice_triggers: [
      {
        name: 'Initial Eligible Employer open enrollment begins',
        notice_template: 'notices/shop_employer_notices/initial_employer_open_enrollment_begins',
        notice_builder: 'ShopEmployerNotices::InitialEmployerOpenEnrollmentBegin',
        mpi_indicator: 'MPI_SHOP16',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'SHOP16_B',
    title: 'Initial Eligible Employee Open Enrollment Period begins',
    description: 'When Employer application meets minimum participation and non-owner requirements',
    resource_name: 'employee_role',
    event_name: 'initial_employee_open_enrollment_begins',
    notice_triggers: [
      {
        name: 'Initial Eligible Employee open enrollment begins',
        notice_template: 'notices/shop_employee_notices/16b_initial_employee_open_enrollment_begins',
        notice_builder: 'ShopEmployeeNotices::InitialEmployeeOpenEnrollmentBegin',
        mpi_indicator: 'MPI_SHOP16_B',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employee"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'SHOP17',
    title: 'Open Enrollment Completed',
    description: 'All initial Employers who complete their initial Open Enrollment Period and satisfy the minimum participation and non-owner enrollmnet requirements',
    resource_name: 'employer',
    event_name: 'initial_employer_open_enrollment_completed',
    notice_triggers: [
      {
        name: 'Initial Employee Open Enrollment Successfully Completed',
        notice_template: 'notices/shop_employer_notices/17_initial_employer_open_enrollment_completed',
        notice_builder: 'ShopEmployerNotices::InitialEmployerOpenEnrollmentCompleted',
        mpi_indicator: 'MPI_SHOP17',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP13',
    title: 'Open Enrollment Reminder',
    description: 'This notices goes to all the employees in the open enrollment period',
    resource_name: 'employee_role',
    event_name: 'employee_open_enrollment_reminder',
    notice_triggers: [
      {
        name: 'Employee Open Enrollment Reminder Notice',
        notice_template: 'notices/shop_employee_notices/13_employee_open_enrollment_reminder',
        notice_builder: 'ShopEmployeeNotices::EmployeeOpenEnrollmentReminderNotice',
        mpi_indicator: 'MPI_SHOP13',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employee"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'SHOP20',
    title: 'Your Invoice for Employer Sponsored Coverage is Now Available',
    description: 'When initial groups first invoice is available in their account, this notice is sent to them to instruct them on how to pay their binder payment.',
    resource_name: 'employer',
    event_name: 'initial_employer_invoice_available',
    notice_triggers: [
      {
        name: 'Initial Employer first invoice available in the account',
        notice_template: 'notices/shop_employer_notices/initial_employer_invoice_available_notice',
        notice_builder: 'ShopEmployerNotices::InitialEmployerInvoiceAvailable',
        mpi_indicator: 'MPI_SHOP20',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  
  {
    hbx_id: 'SHOP27',
    title: 'Final Reminder to publish Application',
    description: 'All the initial employers with draft plan years will be notified to publish their plan year on 3rd of the month.',
    resource_name: 'employer',
    event_name: 'initial_employer_final_reminder_to_publish_plan_year',
    notice_triggers: [
      {
        name: 'Initial Employer Application, Deadline Extended - Reminder to publish',
        notice_template: 'notices/shop_employer_notices/initial_employer_reminder_to_publish_plan_year',
        notice_builder: 'ShopEmployerNotices::InitialEmployerReminderToPublishPlanYear',
        mpi_indicator: 'MPI_SHOP27',
        notice_trigger_element_group: {
          market_places: ['shop'],
          primary_recipients: ["employer"],
          primary_recipient_delivery_method: ["secure_message"],
          secondary_recipients: []
        }
      }
    ]
  },
  
]



ivl_notice_triggers = [
  {
    hbx_id: 'VerificationBacklog',
    title: 'Documents needed to confirm eligibility for your plan',
    description: 'Should be triggered for thoso who completed Enroll App application but verifications pending',
    resource_name: 'consumer_role',
    event_name: 'verifications_backlog',
    notice_triggers: [
      {
        name: 'Outstanding Verification Notification',
        notice_template: 'notices/ivl/verifications_backlog_notice',
        notice_builder: 'IvlNotices::ConsumerNotice',
        mpi_indicator: 'MPI_IVLV5B',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'Notice20A',
    title: 'Request for Additional Information - First Reminder',
    description: 'After 10 days passed, notice to be sent to Consumers informing them of the outstanding verifications',
    resource_name: 'consumer_role',
    event_name: 'first_verifications_reminder',
    notice_triggers: [
      {
        name: 'First Outstanding Verification Notification',
        notice_template: 'notices/ivl/documents_verification_reminder1',
        notice_builder: 'IvlNotices::ConsumerNotice',
        mpi_indicator: 'MPI_IVLV20A',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'Notice20B',
    title: 'Request for Additional Information - Second Reminder',
    description: 'After 25 days passed, notice to be sent to Consumers informing them of the outstanding verifications',
    resource_name: 'consumer_role',
    event_name: 'second_verifications_reminder',
    notice_triggers: [
      {
        name: 'Second Outstanding Verification Notification',
        notice_template: 'notices/ivl/documents_verification_reminder2',
        notice_builder: 'IvlNotices::ConsumerNotice',
        mpi_indicator: 'MPI_IVLV20B',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'Notice21',
    title: 'Request for Additional Information - Third Reminder',
    description: 'After 50 days passed, notice to be sent to Consumers informing them of the outstanding verifications',
    resource_name: 'consumer_role',
    event_name: 'third_verifications_reminder',
    notice_triggers: [
      {
        name: 'Third Outstanding Verification Notification',
        notice_template: 'notices/ivl/documents_verification_reminder3',
        notice_builder: 'IvlNotices::ConsumerNotice',
        mpi_indicator: 'MPI_IVLV21',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'Notice22',
    title: 'Request for Additional Information - Fourth Reminder',
    description: 'After 65 days passed, notice to be sent to Consumers informing them of the outstanding verifications',
    resource_name: 'consumer_role',
    event_name: 'fourth_verifications_reminder',
    notice_triggers: [
      {
        name: 'Fourth Outstanding Verification Notification',
        notice_template: 'notices/ivl/documents_verification_reminder4',
        notice_builder: 'IvlNotices::ConsumerNotice',
        mpi_indicator: 'MPI_IVLV22',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'IVLR1',
    title: '2017 Health Insurance Coverage and Preliminary Renewal Information',
    description: 'Notice to be sent out to individuals with UQHP(Unassisted)',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_1',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice',
        notice_template: 'notices/ivl/ivlr_1_uqhp_projected_renewal_notice',
        notice_builder: 'IvlNotices::IvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR1',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'IVLR1',
    title: '2017 Health Insurance Coverage and Preliminary Renewal Information',
    description: 'Notice to be sent out to individuals with UQHP(Unassisted)',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_1_second_batch',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice',
        notice_template: 'notices/ivl/ivlr1_notice_second_batch_without_ea_data',
        notice_builder: 'IvlNotices::IvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR1B',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'IVLR2',
    title: '2017 Health Insurance Coverage and Preliminary Renewal Information',
    description: 'Notice to be sent out to individuals staying in APTC only',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_2',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice',
        notice_template: 'notices/ivl/ivlr_2_projected_renewal_notice',
        notice_builder: 'IvlNotices::SecondIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR2',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'IVLR3',
    title: '2017 Health Insurance Coverage and Preliminary Renewal Information',
    description: 'Notice to be sent out to individuals moving from APTC to Medicaid',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_3',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice',
        notice_template: 'notices/ivl/IVLR_3_APTC_Medicaid',
        notice_builder: 'IvlNotices::SecondIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR3',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },

  {
    hbx_id: 'IVLR4',
    title: '2017 Health Insurance Coverage and Preliminary Renewal Information',
    description: 'Notice to be sent out to individuals moving from APTC to UQHP',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_4',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice',
        notice_template: 'notices/ivl/IVLR4_APTC_uqhp',
        notice_builder: 'IvlNotices::SecondIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR4',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'IVLR8',
    title: '2017 Insurance Renewal Notice and Opportunity to Change Plans',
    description: 'Notice to be sent out to individuals staying on UQHP',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_8',
    notice_triggers: [
      {
        name: 'September Projected Renewal Notice - UQHP',
        notice_template: 'notices/ivl/IVLR8_UQHP_to_UQHP',
        notice_builder: 'IvlNotices::VariableIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR8',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'IVLR9',
    title: 'Your 2017 Final Insurance Enrollment Notice',
    description: 'Notice to be sent out to people enrolled in 2017 coverage who have enrolled by December',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_9',
    notice_triggers: [
      {
        name: 'December Final Insurance Enrollment Notice',
        notice_template: 'notices/ivl/IVLR9_UQHP_final_renewal_december',
        notice_builder: 'IvlNotices::NoAppealVariableIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR9',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'IVLR10',
    title: 'Your 2017 Final Insurance Enrollment Notice',
    description: 'Notice to be sent out to people enrolled in 2017 assisted coverage who have enrolled by December',
    resource_name: 'consumer_role',
    event_name: 'ivl_renewal_notice_10',
    notice_triggers: [
      {
        name: 'December Final Insurance Enrollment Notice',
        notice_template: 'notices/ivl/IVLR10_AQHP_final_renewal',
        notice_builder: 'IvlNotices::NoAppealVariableIvlRenewalNotice',
        mpi_indicator: 'MPI_IVLR10',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
  {
    hbx_id: 'IVL_CAT16',
    title: 'Important Tax Information about your Catastrophic Health Coverage',
    description: 'Notice to be sent out to all the people enrolled in Catastrophic plan in 2016 for at least one month',
    resource_name: 'consumer_role',
    event_name: 'final_catastrophic_plan_2016',
    notice_triggers: [
      {
        name: 'Final Catastrophic Plan Notice',
        notice_template: 'notices/ivl/final_catastrophic_plan_letter',
        notice_builder: 'IvlNotices::FinalCatastrophicPlanNotice',
        mpi_indicator: 'MPI_CAT16',
        notice_trigger_element_group: {
          market_places: ['individual'],
          primary_recipients: ["consumer"],
          primary_recipient_delivery_method: ["secure_message", "paper"],
          secondary_recipients: []
        }
      }
    ]
  },
]


shop_notice_triggers.each do |trigger_params|
  ApplicationEventKind.create(trigger_params)
end

ivl_notice_triggers.each do |trigger_params|
  ApplicationEventKind.create(trigger_params)
end



