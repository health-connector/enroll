class Organizers::MembersSelectionPrevaricationAdapter
    include Interactor::Organizer

    organize [
        FindPerson
        FindPrimaryFamily
    ]

end