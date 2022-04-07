$(document).ready(function () {
  $('#employer_profile_legal_name').click(function () {
    var person_id = $("#person_id").val();
    var market_kind = $("#market_kind").val();
    var employee_role_id = $("#employer_profile_legal_name").val();
    var event = $("#event").val();

    console.log('here')
    $.ajax({
      type: 'GET',
      data: {
        person_id: person_id,
        employee_role_id: employee_role_id,
        new_effective_on: "",
        market_kind: market_kind,
        event: event
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

  $('#eligible_continue_yes, #eligible_continue_no').on('click', function(e) {
    console.log($(this).data('href'))
    console.log('something')
    debugger;
    var href = $(this).data('href')
    console.log(href)
    $('#eligible-btn-continue').attr('href', href)    
  })
});