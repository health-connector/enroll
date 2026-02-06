// 1. GLOBAL JQUERY SETUP (CRITICAL)
import $ from 'jquery';
window.jQuery = $;
window.$ = $;

import "expose-loader?exposes=bowser!../../vendor/assets/javascripts/bowser.min.js";
// IMPORT AND ASSIGN MANUALLY
import Bowser from "../../vendor/assets/javascripts/bowser.min.js";
window.bowser = Bowser;

// 2. CORE RAILS LIBRARIES
import Rails from "@rails/ujs";
Rails.start();

import Turbolinks from "turbolinks";
Turbolinks.start();

// 3. VENDOR LIBRARIES (Exposing globals where needed)
import "bootstrap/dist/js/bootstrap.bundle";
import "../../vendor/assets/javascripts/jquery.selectric.min.js";
import "../../vendor/assets/javascripts/jquery.mask.js";
import "../../vendor/assets/javascripts/floatlabels.js";

// DataTables
// import "datatables.net";
// import "datatables.net-bs";
// import "../../project_gems/effective_datatables-2.6.14/app/assets/javascripts/dataTables/responsive/dataTables.responsive.js"
import "../../vendor/assets/javascripts/dataTables/jquery.dataTables";
import "../../vendor/assets/javascripts/dataTables/jquery.dataTables";
import "../../vendor/assets/javascripts/dataTables/bootstrap/3/jquery.dataTables.bootstrap";
import "../../vendor/assets/javascripts/bootstrap-treeview";

window.DataTable = $.fn.dataTable;
window.DT = $.fn.dataTable;

// 4. LEGACY APPLICATION CODE
import "../assets/javascripts/classie.js";
import "../assets/javascripts/modalEffects.js";
import "../assets/javascripts/override_confirm.js";
import "../assets/javascripts/dob_validation.js";
import "../assets/javascripts/date.js";
import "../assets/javascripts/formhelpers.js";
import "../assets/javascripts/modal_actions.js";
import "../assets/javascripts/print.js";
import "../assets/javascripts/browser_issues.js";
import "../assets/javascripts/consumer_role.js";
import "../assets/javascripts/aptc.js";
import "../assets/javascripts/announcement.js";
import "../assets/javascripts/bootstrap-slider.js";
import "../assets/javascripts/general_agency.js";
import "../assets/javascripts/freebies.js";
import "../assets/javascripts/responsive.js";
import "../assets/javascripts/jquery.steps.js";
import "../assets/javascripts/set_tab_content.js"
import "../assets/javascripts/semantic_class.js"

window.disableSelectric = false;

$(document).on('ready page:load turbolinks:load ajax:success', function () {
    Freebies.fadeElement($("body"));
    Freebies.allFreebies();
    Responsive.setSizeListeners();
});

window.applyMultiLanguageSelect = function() {
    $('#broker_agency_language_select').multiselect({
        nonSelectedText: 'Select Language',
        maxHeight: 300
    });
    $('#broker_agency_language_select').multiselect('select', 'en', true);
    $('#broker_agency_language_select').on('selectric-init', function(element){
        $('.language_multi_select .selectric-interaction-field-control-broker-agency-languages-spoken').hide();
    });
};

window.applyMultiLanguageSelectForGA = function() {
    $('#general_agency_language_select').multiselect({
        nonSelectedText: 'Select Language',
        maxHeight: 300
    });
    $('#general_agency_language_select').multiselect('select', 'en', true);
    $('#general_agency_language_select').on('selectric-init', function(element){
        $('.language_multi_select .selectric-interaction-field-control-general-agency-languages-spoken').hide();
    });
};

window.dchbx_enroll_date_of_record = function() {
    return new Date($('#dchbx_enroll_date_of_record').text());
};

window.getCarrierPlans = function(ep, ci) {
    let params = 'carrier_id=' + ci;
    $.ajax({
        url: "/employers/employer_profiles/"+ep+"/plan_years/reference_plans/",
        data: params
    })
};

$(document).on('click', '#modal-wrapper div label', function(){
    $(this).closest('div').find('input[type=file]').on('change', function() {
        let filename = $(this).closest('div').find('input[type=file]').val()
        $(this).closest('div').find('.select').hide();
        $(this).closest('div').find('.upload-preview').html(filename + "<i class='fa fa-times fa-lg pull-right'></i>").show();
        $(this).closest('div').find('input[type=submit]').css({"visibility": "visible", "display": "inline-block"});
    });
});

$(document).on('click', '.upload-preview .fa', function(){
    $(this).closest('#modal-wrapper').find('input[type=file]').val("");
    $(this).closest('#modal-wrapper').find('.upload-preview').hide();
    $(this).closest('#modal-wrapper').find('input[type=submit]').hide();
    $(this).closest('#modal-wrapper').find('.select').show();
});
$(document).on('click', '#modal-wrapper .modal-close', function(){
    $(this).closest('#modal-wrapper').remove();
});

$(document).on('ready turbolinks:load ajax:success', function () {

    $('.module a.view-more').on('click', function() {
        event.preventDefault();
        if ( $(this).hasClass('view-less') ) {
            $(this).html('View More<i class="fa fa-chevron-down"></i>');
            $(this).removeClass('view-less');
            $(this).closest('.section').find('.dn').slideUp();
        } else {
            $(this).html('View Less<i class="fa fa-chevron-up"></i>');
            $(this).addClass('view-less');
            if ( $(this).closest('.module').hasClass('employer-welcome') ) {
                $(this).closest('.section').find('.dn').slideDown();
            }
        }
    });

    $('.email-alert').on('click', function() {
        let siteShortName = document.body.dataset.siteShortName || "Exchange";

        let msg = "You are leaving the " + siteShortName + " web site and entering a privately owned web site created, operated and maintained by a private business. The information that this private business collects and maintains as a result of your visit to its web site is different from the information that the " + siteShortName + " collects and maintains. " + siteShortName + " does not share information with this private company. " + siteShortName + " cannot help you with any information regarding this website, including your username or password, or other technical issues. By linking to this private business, the " + siteShortName + " is not endorsing its products, services, or privacy or security policies. We recommend you review the business's information collection policy or terms and conditions to fully understand what information is collected by this private business.";

        if ( !confirm(msg) ) { return false; }
    })

    if ( $('.plan-year').find('.fa-star.enrolling, .fa-star.published').length )  {
        $('.plan-year').find('.fa-star.enrolling, .fa-star.published').closest('.plan-year').find('a.benefit-details').trigger('click');
    }

    $.fn.toggleClick=function(){
        let functions=arguments, iteration=0
        return this.click(function(){
            functions[iteration].apply(this,arguments)
            iteration= (iteration+1) %functions.length
        })
    }

    $(document).on('click', '.table-functions i.fa-trash-o', function()  {
        $(this).closest("tr").next().show();
        $(this).closest("tr").hide();
    });
    $(document).on('click', 'a.terminate.cancel', function()  {
        $(this).closest('tr').prev().show();
        $(this).closest('tr').hide();
    });

    // details toggler
    $('.benefitgroup .details').toggleClick(function () {
        $(this).closest('.referenceplan').find('.plan-details').slideDown();
        $(this).html('Hide Details <i class="fa fa-chevron-up fa-lg"></i>');
    }, function () {
        $(this).closest('.referenceplan').find('.plan-details').slideUp();
        $(this).html('View Details <i class="fa fa-chevron-down fa-lg"></i>');
    });

    // toggle filter options in employees list
    $(document).on('click', '.filter-options label', function()  {
        $('.filter-options').hide();
    });
    $(document).on('mouseleave', '.filter-options', function()  {
        $('.filter-options').hide();
    });

    $('a.back').click(function(){
        parent.history.back();
        return false;
    });

    semantic_class(); //Calls semantic class on all input fields & buttons (eg. interaction-click-control-continue)


    $(document).on("focus", "[class~='date-picker']", function(e){
        dateMin = $(this).attr("data-date-min");
        dateMax = $(this).attr("data-date-max");

        if ($(this).hasClass('dob-picker') || $(this).hasClass('hire-picker')){
            $(this).datepicker({
                changeMonth: true,
                changeYear: true,
                dateFormat: 'mm/dd/yy',
                maxDate: "+0d",
                yearRange: dchbx_enroll_date_of_record().getFullYear()-110 + ":" + dchbx_enroll_date_of_record().getFullYear(),
                onSelect: function(dateText, dpInstance) {
                    $(this).datepicker("hide");
                    $(this).trigger('change');
                }
            });
        }else{
            $(this).datepicker({
                changeMonth: true,
                changeYear: true,
                dateFormat: 'mm/dd/yy',
                minDate: dateMin,
                maxDate: dateMax,
                yearRange: dchbx_enroll_date_of_record().getFullYear()-110 + ":" + (dchbx_enroll_date_of_record().getFullYear() + 10),
                onSelect: function(dateText, dpInstance) {
                    $(this).datepicker("hide");
                    $(this).trigger('change');
                }
            });
        }
    });

    $(".address-li").on('click',function(){
        $(".address-span").html($(this).data("address-text"));
        $(".address-row").hide();
        divtoshow = $(this).data("value") + "-div";
        $("."+divtoshow).show();
    });
    // Add something similar to jqueries deprecated .toggle()
    $.fn.toggleClick=function(){
        var functions=arguments, iteration=0
        return this.click(function(){
            functions[iteration].apply(this,arguments)
            iteration= (iteration+1) %functions.length
        })
    }

    $( "#new_person" ).submit(function( event ) {
        $('#person_first_name, #person_middle_name, #person_last_name').each(function() {
            var name = $(this).val();
            var trimmed_name = $.trim(name)
            $(this).val(trimmed_name);
        });
    });

    // personal-info-row focus fields
    $(document).on('focusin', 'input.form-control', function() {
        $(this).parents(".row-form-wrapper").addClass("active");
        $(this).prev().addClass("active");
    });

    $(document).on('focusout', 'input.form-control', function() {
        $(this).parents(".row-form-wrapper").removeClass("active");
        $(this).prev().removeClass("active");
        $("img.arrow_active").remove();
    });

    $('.employer_step2').click(function() {

        // Display correct sidebar
        $('.credential_info').addClass('hidden');
        $('.name_info').addClass('hidden');
        $('.tax_info').addClass('hidden');
        $('.emp_contact_info').removeClass('hidden');
        $('.coverage_info').removeClass('hidden');
        $('.plan_selection_info').removeClass('hidden');

        // Display correct form fields
        $('#credential_info').addClass('hidden');
        $('#name_info').addClass('hidden');
        $('#tax_info').addClass('hidden');

        $('#emp_contact_info').removeClass('hidden');
        $('#coverage_info').removeClass('hidden');
        $('#plan_selection_info').removeClass('hidden');
    });

    $('.employer_step3').click(function() {

        // Display correct sidebar
        $('.emp_contact_info').addClass('hidden');
        $('.coverage_info').addClass('hidden');
        $('.plan_selection_info').addClass('hidden');

        $('.emp_contributions_info').removeClass('hidden');
        $('.eligibility_rules_info').removeClass('hidden');
        $('.broker-info').removeClass('hidden');

        // Display correct form fields
        $('#emp_contact_info').addClass('hidden');
        $('#coverage_info').addClass('hidden');
        $('#plan_selection_info').addClass('hidden');

        $('#emp_contributions_info').removeClass('hidden');
        $('#eligibility_rules_info').removeClass('hidden');
        $('#broker_info').removeClass('hidden');
    });

    $(document).on('click', '.close-fail', function() {
        $(".fail-search").addClass('hidden');
        $(".overlay-in").css("display", "none");
    });

    // ----- Focus Effect & Progress -----
    $("body").click(function(e) {
        update_progress();
    });

    update_progress(); //Run on page load for dependent_details page.
    function update_progress() {
        var start_progress = $('#initial_progress').length ? parseInt($('#initial_progress').val()) : 0;

        if(start_progress == 0) {
            var personal_entry = check_personal_entry_progress();
            var address_entry  = check_address_entry_progress();
            var phone_entry    = check_phone_entry_progress();
            var email_entry    = check_email_entry_progress();
        }

        if(personal_entry) {
            start_progress = 10;
            $("a.one, a.two").css("color","#00b420");
        }

        if(address_entry) {
            start_progress += 8;
            $("a.three").css("color","#00b420");
        }

        if(phone_entry) {
            start_progress += 10;
            $("a.four").css("color","#00b420");
        }

        if(email_entry) {
            start_progress += 12;
            $("a.five").css("color","#00b420");
        }

        if($('.dependent_list').length) {
            start_progress += 5;
            $("a.six").css("color","#00b420");
        }

        if($('#family_member_ids_0').length) {
            $("a.seven").css("color","#00b420");
        }

        if($('#all-plans').length) {
            $("a.eight").css("color","#00b420");
        }

        if($('#confirm_plan').length) {
            $("a.nine").css("color", "#00b420");
        } else {
            //      $("a.six").css("color","#999");
        }

        $('#top-pad').html(start_progress + '% Complete');
        $('.progress-top').css('height', start_progress + '%');

        if(start_progress >= 40) {
            $('#continue-employer').removeClass('disabled');
        } else {
            $('#continue-employer').addClass('disabled');
        }
    }

    function check_personal_entry_progress() {
        let gender_checked = $("#person_gender_male").prop("checked") || $("#person_gender_female").prop("checked");
        if(gender_checked==undefined) {
            return true;
        }
        if(check_personal_info_exists().length==0 && gender_checked) {
            return true;
        } else {
            $("a.one").css('color', '#999'); $("a.two").css('color', '#999');
            return false;
        }
    }

    function check_address_entry_progress() {
        var empty_address = $('#address_info input.required').filter(function() { return $(this).val() === ""; }).length;
        if(empty_address === 0) { return true; }
        else {
            $("a.three").css('color', '#999');
            return false;
        }
    }

    function check_phone_entry_progress() {
        var empty_phone = $('#phone_info input.required').filter(function() { return ($(this).val() === "" || $(this).val() === "(___) ___-____"); }).length;
        if(empty_phone === 0) { return true; }
        else {
            $("a.four").css('color', '#999');
            return false;
        }
    }

    function check_email_entry_progress() {
        var empty_email = $('#email_info input.required').filter(function() { return $(this).val() === ""; }).length;
        if(empty_email === 0) { return true; }
        else {
            $("a.five").css('color', '#999');
            return false;
        }
    }
    // ----- Finish Focus Effect & Progress -----
});


$(document).on('change', "#plan_year_start_on", function() {
    var dental_target_url = $('a#generate-dental-carriers-and-plans').attr('href');
    var plan_year_id = $('a#generate-dental-carriers-and-plans').data('planYearId');
    var location_id = $('.benefit-group-fields:last').attr('id');
    var active_year = $(this).val().substr(0,4);

    var dentalPlanYears = JSON.parse(document.body.dataset.dentalPlanYears || "[]");

    if($.inArray(active_year, dentalPlanYears) !== -1){
        $(".show-dental-plans").show();
    }else{
        $(".show-dental-plans").hide();
    }
});

