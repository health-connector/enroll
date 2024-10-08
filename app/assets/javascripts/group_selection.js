$(document).on("ready turbolinks:load", function() {
  setGroupSelectionHandlers();
});

function setGroupSelectionHandlers(){

  var employers = $("[id^=census_employee_]");
  hideAllErrors();

  if ($("#employer-selection .n-radio-group .n-radio-row").length) {

    var checked_er = $("#employer-selection .n-radio-group .n-radio-row input[checked^= 'checked']:enabled");

    if (checked_er.length) {
      var employer_id = checked_er.val();
      if ($('#coverage_kind_health').is(':checked')) {
        $(".health_errors_" + employer_id ).show();
      }

      if ($('#coverage_kind_dental').is(':checked')) {
        $(".dental_errors_" + employer_id ).show();
      }

      setDentalBenefits(checked_er.attr('dental_benefits'));
      errorsForChangeInCoverageKind(employer_id);
      setPrimaryForShop();
    }

  } else {

    $('#dental-radio-button').show();
    $('.ivl_errors').show();
    disableIvlIneligible();
    setPrimaryForIvl();
  }

  if($('#market_kinds').length) {
    var employer_id = ""

    if ( $('#market_kind_individual').is(':checked') ) {
      $('#dental-radio-button').show();
      hideShopErrors();
      $('.ivl_errors').show();

      disableEmployerSelection();
      disableIvlIneligible();
      setPrimaryForIvl();
    }
    $('#market_kind_individual').on('change', function() {
      disableEmployerSelection();

      $('#dental-radio-button').slideDown();
      hideShopErrors();
      $('.ivl_errors').show();

      disableIvlIneligible();
      setPrimaryForIvl();

    });

    $('#market_kind_shop').on('change', function() {
      employers.each( function() {
        $(this).prop("disabled", false);
        if($(this).hasClass('selected_employer')) {
          employer_id = $(this).attr("value")
          $(this).prop("checked", true);
          $(this).removeClass('selected_employer');
          setDentalBenefits($(this).attr('dental_benefits'));
        }
      });

      $("#coverage_kind_health").prop("checked", true);
      hideAllErrors();
      disableShopHealthIneligible(employer_id)
      $(".health_errors_" + employer_id ).show();
      setPrimaryForShop();
    });
  }

  employers.on("change", function(){
    errorsForChangeInEmployer(this);
  })
}

function setPrimaryForIvl() {
  $("tr.is_primary td:first-child input").attr("onclick", "return true;");
  $("tr.is_primary td:first-child input").prop("readonly", false);
}

function setPrimaryForShop() {
  $("tr.is_primary td:first-child input").attr("onclick", "return false;");
  $("tr.is_primary td:first-child input").prop("readonly", true);
}


function hideAllErrors(){
  hideShopErrors();
  hideIvlErrors();
}

function hideShopErrors() {
  $("[class^=dental_errors_]").hide();
  $("[class^=health_errors_]").hide();
}

function hideIvlErrors() {
  $('#coverage-household tr td.ivl_errors').hide();
}

function errorsForChangeInEmployer(element) {
  var employer_id = $(element).attr("value")

  $("#coverage_kind_health").prop("checked", true);

  hideAllErrors();

  $(".health_errors_" + $(element).attr("value") ).show();

  if($(element).is(":checked")){
    setDentalBenefits($(element).attr('dental_benefits'));
  }
  errorsForChangeInCoverageKind(employer_id)
}

function errorsForChangeInCoverageKind(employer_id){
  $('#coverage_kind_health').on('change', function() {
    hideAllErrors();
    if ($("#employer-selection .n-radio-group .n-radio-row input[checked^= 'checked']:enabled").length) {
      
      $(".health_errors_" + employer_id ).show();
      disableShopHealthIneligible(employer_id);

    } else {

      $(".ivl_errors").show();
      disableIvlIneligible();

    }
  });

  $('#coverage_kind_dental').on('change', function() {
    hideAllErrors();
    if ($("#employer-selection .n-radio-group .n-radio-row input[checked^= 'checked']:enabled").length) {
      
      $(".dental_errors_" + employer_id ).show();
      disableShopDentalIneligible(employer_id);

    } else {
      
      $(".ivl_errors").show();
      disableIvlIneligible();
    }
  });
}

function disableIvlIneligible() {
  $('#coverage-household tr').filter("[class^=ineligible_]").not(".ineligible_ivl_row").find('input').prop({'checked': true, 'disabled': false});
  $('#coverage-household tr').filter(".ineligible_ivl_row").find('input').prop({'checked': false, 'disabled': true});
}

function disableShopDentalIneligible(employer_id) {
  $('#coverage-household tr').filter("[class^=ineligible_]").not(".ineligible_dental_row_" + employer_id).find('input').prop({'checked': true, 'disabled': false});
  $('#coverage-household tr').filter(".ineligible_dental_row_" + employer_id).find('input').prop({'checked': false, 'disabled': true});
}

function disableShopHealthIneligible(employer_id) {
  $('#coverage-household tr').filter("[class^=ineligible_]").not(".ineligible_health_row_" + employer_id).find('input').prop({'checked': true, 'disabled': false});
  $('#coverage-household tr').filter(".ineligible_health_row_" + employer_id).find('input').prop({'checked': false, 'disabled': true});
}


function disableEmployerSelection(){
  var employers = $("[id^=census_employee_]");
  employers.each( function() {
    if($(this).is(":checked")) {
      $(this).addClass('selected_employer');
    }
    $(this).prop("disabled", true);
    $(this).prop("checked", false);
  });
}

function setDentalBenefits(dental_benefits){
  if(dental_benefits == 'true'){
    $('#dental-radio-button').slideDown();
  } else {
    $('#dental-radio-button').slideUp();
  }
}

$(document).on('change', '#waiver_reason_selection_dropdown', function() {
	if($(this).val() == undefined || $(this).val() == ""){
		$('#waiver_reason_submit').attr("disabled",true);
	}else{
		$('#waiver_reason_submit').attr("disabled",false);
	}
});

$(function(){
	if ( $("#find_sep_link").length ) {
		$("#find_sep_link").click(function() {
			$(this).closest('form').attr('action', '/insured/families/find_sep');
			$(this).closest('form').attr('method', 'get');
			$(this).closest('form').submit();
		});
	}
})

function onDependentHealthEnroll(e) {}
function onDependentHealthWaive(e) {}
function onDependentDentalEnroll(e) {}
function onDependentDentalWaive(e) {}

function onPrimaryHealthEnroll(e) {
  hideWaiverDetails();
  enableDependentHealthEnroll();
  enableDependentHealthWaive();
  enableConfirmYourSelection();
}

function onPrimaryHealthWaive(e) {
  showWaiverDetails();
  checkAndDisableDependentsHealthWaivers();
  DisableDependentsHealthEnroll();
}

function onPrimaryDentalEnroll(e) {
  enableDependentDentalEnroll();
  enableDependentDentalWaive();
}

function onPrimaryDentalWaive(e) {
  checkAndDisableDependentsDentalWaivers();
  DisableDependentsDentalEnroll();
}

function enableDependentHealthEnroll() {
  $("[id^=health_enroll_dependent]").each(function (index) {
    $("[id^=health_enroll_dependent]")[index].checked = true
    $("[id^=health_enroll_dependent]")[index].disabled = false
  });
}

function enableDependentHealthWaive() {
  $("[id^=health_waive_dependent]").each(function (index) {
    $("[id^=health_waive_dependent]")[index].disabled = false
  });
}

function DisableDependentsHealthEnroll() {
  $("[id^=health_enroll_dependent]").each(function (index) {
    $("[id^=health_enroll_dependent]")[index].checked = false
    $("[id^=health_enroll_dependent]")[index].disabled = true
  });
}

function checkAndDisableDependentsHealthWaivers() {
  $("[id^=health_waive_dependent]").each(function (index) {
    $("[id^=health_waive_dependent]")[index].checked = true
    $($("[id^=health_waive_dependent]")[index]).find(":radio:not(:checked)").prop({"disabled": true})
  });
}

function checkAndDisableDependentsDentalWaivers() {
  $("[id^=dental_waive_dependent]").each(function (index) {
    $("[id^=dental_waive_dependent]")[index].checked = true
    $($("[id^=dental_waive_dependent]")[index]).find(":radio:not(:checked)").prop({"disabled": true})
  });
}

function DisableDependentsDentalEnroll() {
  $("[id^=health_enroll_dependent]").each(function (index) {
    $("[id^=dental_enroll_dependent]")[index].checked = false
    $("[id^=dental_enroll_dependent]")[index].disabled = true
  });
}

function enableDependentDentalEnroll() {
  $("[id^=dental_enroll_dependent]").each(function (index) {
    $("[id^=dental_enroll_dependent]")[index].checked = true
    $("[id^=dental_enroll_dependent]")[index].disabled = false
  });
}

function enableDependentDentalWaive() {
  $("[id^=dental_waive_dependent]").each(function (index) {
    $("[id^=dental_waive_dependent]")[index].disabled = false
  });
}

function hideWaiverDetails() {
  $("[id^=waiver_header_for_primary]").hide();
  $("[id^=waiver_reasons_for_primary]").hide();
}

function showWaiverDetails() {
  $("[id^=waiver_header_for_primary]").show();
  $("[id^=waiver_reasons_for_primary]").show();
}

function onWaiverReasonSelect(elem, isAdmin) {
  if (elem.value == "I am outside of the plan service area" && !isAdmin) {
    $(".interaction-click-control-shop-for-new-plan").attr("disabled", true);
    $('.outside_service_area_waiver_error').removeClass('hidden');
  } else {
    $(".interaction-click-control-shop-for-new-plan").attr("disabled", false);
    $('.outside_service_area_waiver_error').addClass('hidden');
  }
}

function enableConfirmYourSelection() {
  $('#waiver_reason').prop('selectedIndex',0)
  $('select').selectric('refresh');
  $(".interaction-click-control-shop-for-new-plan").attr("disabled", false);
  $('.outside_service_area_waiver_error').addClass('hidden');
}
