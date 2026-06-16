$(function() {
  applyBrokerTabClickHandlers();
});

function applyBrokerTabClickHandlers(){
  $('div[name=broker_agency_tabs] >').children().each( function() {
    $(this).change(function(){
      filter = 'broker';
      agency_type = $(this).attr('value');
      action_url = '/broker_agencies/broker_roles/new_broker.js';
      if (agency_type == 'new') {
        action_url = '/broker_agencies/broker_roles/new_broker_agency.js';
      }
      $.ajax({
        url: action_url,
        type: "GET",
        data : { 'filter': filter, 'agency_type': agency_type }
      });
    })
  })
}

$(function() {
  $('ul[name=broker_signup_primary_tabs] > li > a').on('click', function() {
      filter = $(this).data('value');
      action_url = '/broker_agencies/broker_roles/new_broker.js';
      if (filter == 'staff') {
        action_url = '/broker_agencies/broker_roles/new_staff_member.js';
      }
      $.ajax({
        url: action_url,
        type: "GET",
        data : { 'filter': filter }
      });
  })
})

