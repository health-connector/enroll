$(document).ready(function () {
  $('#employer_profile_legal_name').click(function () {
    var person_id = $("#person_id").val();
    var market_kind = $("#market_kind").val();
    var employee_role_id = $("#employer_profile_legal_name").val();

    console.log('here')
    $.ajax({
      type: 'GET',
      data: {
        person_id: person_id,
        employee_role_id: employee_role_id,
        new_effective_on: "",
        market_kind: market_kind
      },
      url: '/insured/members_selections/fetch',
      success: function (data) {
        console.log(data)

      },
      error: function (data) {
        console.log(data)
      }
    });
  });
});