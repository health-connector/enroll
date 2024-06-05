$(document).on('ready turbolinks:load', function () {
  var employers = $("[id^=employee_role_id_]");
  employers.on("change", function(){
    var person_id = $("#person_id").val();
    var market_kind = $("#market_kind").val();
    var employee_role_id = this.value;
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
    var href = $(this).data('href')
    $('#eligible-btn-continue').attr('href', href)
  })
});
