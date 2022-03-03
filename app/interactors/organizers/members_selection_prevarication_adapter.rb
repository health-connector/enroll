class Organizers::MembersSelectionPrevaricationAdapter
  include Interactor::Organizer

  organize [FindPerson,
            FindPrimaryFamily,
            FindImmediateFamilyCoverageHousehold,
            AssignParamsToContext,
            AssignPreviousHbxEnrollment]
end