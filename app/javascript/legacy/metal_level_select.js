import "core-js/";

(function() {
  // Clears localStorage on page load
  localStorage.removeItem("title");
  localStorage.removeItem("contributionLevels");
})();

function radioSelected(element) {
  setCircle(element)
  disableNewPlanYearButton()
  // Store radio title to localStorage
  const selectedTitle = element.innerText;
  localStorage.setItem("title",selectedTitle);
}

function getPlanInfo(element) {
  let selectedName = element.dataset.name;
  let filteredProducts = planOptions[productOptionKind][selectedName];
  // Sort by plan title
  filteredProducts.sort(function(a,b) {
    if (a.title < b.title) return -1;
    if (a.title > b.title) return 1;
    return 0;
  })
  populateReferencePlans(filteredProducts)
  setTempCL()
  selectDefaultReferencePlan()
}

function populateReferencePlans(plans) {
  window.sponsorContribution = window.sponsorContributions[window.productOptionKind]['contribution_levels'];

  document.getElementById('yourSponsorContributions').innerHTML = window.MetalLevelSelect_SponsorContributionsShell;

  // Makes reference plans visible
  document.getElementById('referencePlans').classList.remove('hidden');
  // Replace below statement with plain Javascript
  window.$('[data-toggle="tooltip"]').tooltip();
  // Removes reference plans if metal level changes
  let populatedReferencePlans = document.querySelectorAll("#yourAvailablePlans");

  if (populatedReferencePlans) {
    for (let i = 0; i < populatedReferencePlans.length; i++) {
      let rplans = populatedReferencePlans[i];
      rplans.remove();
    }
  }

  let referencePlanName;
  if (document.querySelector('input#sponsored_benefits_kind'))
    referencePlanName = "sponsored_benefits[reference_plan_id]";
  else
    referencePlanName = "benefit_package[sponsored_benefits_attributes][0][reference_plan_id]"

  // Build reference plans to be displayed in UI
  for (let i = 0; i < window.filteredProducts.length; i++) {
    let plan = window.filteredProducts[i];
    window.productsTotal = window.filteredProducts.length;
    let div = document.createElement('div');
    document.getElementById('yourPlanTotals').innerHTML = '<span class="pull-right mr-3">Displaying: <b>' + window.filteredProducts.length + ' plans</b></span>';
    div.setAttribute('id', 'yourAvailablePlans');
      let network = "";
      if (plan.network_information)
        network = 'NETWORK NOTES <a data-toggle="tooltip" data-placement="top" data-container="body" title="' + plan.network_information + '"><i class="fas fa-question-circle"></i></a>';
      div.innerHTML =
      '<div class="col-xs-4 reference-plans">' +
        '<div class="col-xs-12 p0 mb-1">' +
          '<label class="container">' +
            '<p class="heading-text reference-plan-title mb-1"> ' + plan.title + '</p>' +
            '<span class="plan-label">Type:</span> <span class="rp-plan-info">' + plan.product_type + '</span><br>' +
            '<span class="plan-label">Carrier:</span> <span class="rp-plan-info">' + plan.carrier_name + '</span><br>' +
            '<span class="plan-label">Level:</span> <span class="rp-plan-info">' + plan.metal_level_kind + '</span><br>' +
            '<span class="plan-label">Network:</span> <span class="rp-plan-info">' + plan.network + '</span><br>' +
            '<span class="plan-label mt-1" onclick="MetalLevelSelect.viewSummary(this)" data-plan-title="' + plan.title + '" data-plan-id="' + plan.id + '">View Summary</span><br>' +
            '<input type="radio" name="' + referencePlanName + '" id="' + plan.id + '" onclick="MetalLevelSelect.newContributionAmounts()" value="' + plan.id + '" data-plan-title="' + plan.title + '" data-plan-carrier="' + plan.carrier_name + '" data-plan-id="' + plan.id + '" data-plan-metal-level="' + plan.metal_level_kind + '" data-plan-type="' + plan.product_type + '" data-network="' + plan.network + '">' +
            '<span class="checkmark"></span>' +
          '</label>' +
        '</div>' +
      '</div>';

      let yourPlans = document.getElementById('yourPlans');
      yourPlans.insertBefore(div, yourPlans.children[-1] || null);
  }

  setTimeout(function() {
    buildSponsorContributions(window.sponsorContribution)
    disableEmployeeContributionLevel();
    newContributionAmounts();
  },400);
}

function setCircle(element) {
  let items = document.querySelectorAll('#metal-level-select ul li');

  for (let i = 0; i < items.length; i++) {
    let li = items[i];
    li.querySelector('i').classList.remove('fa-dot-circle');
  }
  // Sets radio icon to selected
  window.setTimeout(function() {
    if (element.classList.contains('active')) {
      element.querySelector('i').classList.add('fa-dot-circle');
    }
  },200);

  // Gets product option info
  window.productOptionKind = element.querySelector('a').dataset.name;
  // Sets kind to hidden input field for form submission
  let ppKind;
  if (ppKind = document.getElementById('ppKind'))
    ppKind.setAttribute('value', window.productOptionKind);
  document.getElementById('referencePlans').classList.add('hidden');
}

function newContributionAmounts() {
  let contributionInputs = document.querySelectorAll("[data-contribution-input='true']")
  let contributionHandlers = document.querySelectorAll(".contribution_handler")

  for (let i = 0; i < contributionInputs.length; i++) {
    let element = contributionInputs[i];
    switch (element.dataset.displayname) {
      case 'Employee':
        window.eeContribution = element.value;
        if (window.eeContribution > 0) {
          window.tempContributionValues.eeContribution = parseInt (window.eeContribution);
        }
      break;
      case 'Spouse':
        window.spouse = element.value;
        if (window.spouse > 0) {
          window.tempContributionValues.spouse = parseInt (window.spouse);
        }
      break;
      case 'Domestic Partner':
        window.domesticPartner = element.value;
        if (window.domesticPartner > 0) {
          window.tempContributionValues.domesticPartner = parseInt (window.domesticPartner);
        }
      break;
      case 'Child Under 26':
        window.childUnder26 = element.value;
        if (window.childUnder26 > 0) {
          window.tempContributionValues.childUnder26 = parseInt (window.childUnder26);
        }
      break;
      case 'Employee Only':
        window.employeeOnly = element.value;
        if (window.employeeOnly) {
          window.tempContributionValues.employeeOnly = parseInt (window.employeeOnly);
        }
      break;
      case 'Family':
        window.familyOnly = element.value;
        if (familyOnly > 0) {
          window.tempContributionValues.familyOnly = parseInt (window.familyOnly);
        }
      break;
    }

    let tempLevels = JSON.stringify(window.tempContributionValues);
    localStorage.setItem("contributionLevels",tempLevels);
  }

  for (i = 0; i < contributionHandlers.length; i++) {
    let element = contributionHandlers[i];
    switch (element.dataset.displayname) {
      case 'Employee':
        if(!(element.checked)) {
          window.eeContribution = 100;
        }
      break;
      case 'Spouse':
        if(!(element.checked)) {
          window.spouse = 100;
        }
      break;
      case 'Domestic Partner':
        if(!(element.checked)) {
          window.domesticPartner = 100;
        }
      break;
      case 'Child Under 26':
        if(!(element.checked)) {
          window.childUnder26 = 100;
        }
      break;
      case 'Employee Only':
        if(!(element.checked)) {
          window.employeeOnly = 100;
        }
      break;
      case 'Family':
        if(!(element.checked)) {
          window.familyOnly = 100;
        }
      break;
    }
  }
  if (!(document.querySelectorAll(".reference-plans input[type='radio']:checked").length)) {
    disableNewPlanYearButton()
  } else {
    if (applicationStartOn === "01-01") {
      enableNewPlanYearButton()
    } else {
      if (window.eeContribution < window.erCL || window.employeeOnly < window.erCL) {
        disableNewPlanYearButton()
      } else if (window.familyOnly < window.familyCL || window.spouse < window.familyCL || window.domesticPartner < window.familyCL || window.childUnder26 < window.familyCL) {
        disableNewPlanYearButton()
      }  else {
        enableNewPlanYearButton()
      }
    }
  }
  displayReferencePlanDetails(document.querySelector("input[name='benefit_package[sponsored_benefits_attributes][0][reference_plan_id]']:checked"));
}

function disableEmployeeContributionLevel(){
  document.querySelectorAll(".contribution_handler").forEach(function(element) {
    if(element.dataset.displayname == 'Employee' || element.dataset.displayname == "Employee Only" ) {
      element.closest('label').getElementsByTagName('span')[0].classList.add("blocking")
    }
  })
}

function buildSponsorContributions(contributions) {
  let element = document.getElementById('benefitFields');
  Array.from(element.children).forEach(function(child) { child.remove(); });

  let index = 0;

  for (let i = 0; i < contributions.length; i++) {
    let contribution = contributions[i];
    index += 1;
    let attrPrefix;
    if (document.querySelector('input#sponsored_benefits_kind'))
      attrPrefix = 'sponsored_benefits[sponsor_contribution_attributes][contribution_levels_attributes][' + index + ']';
    else
      attrPrefix = 'benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][' + index + ']';
    let div = document.createElement('div');
    div.setAttribute('id', 'yourAvailableContributions');
    div.innerHTML =
    '<div class="row">\
      <input id="' + attrPrefix + '[id]" name="' + attrPrefix + '[id]" type="hidden" value="' + contribution['id'] + '" />\
      <input id="' + attrPrefix + '[contribution_unit_id]" name="' + attrPrefix + '[contribution_unit_id]" type="hidden" value="' + contribution['contribution_unit_id'] + '" />\
        <div class="col-xs-6 pr-3">\
          <div class="row sc-container">\
            <div class="col-xs-12 ml-2 mt-2">\
              <label class="container ml-1">' +contribution.display_name+'\
                <input type="checkbox" checked="checked" id="' + attrPrefix + '[is_offered]" class="contribution_handler" name="' + attrPrefix +'[is_offered]" value="' + contribution["is_offered"] +'" data-displayname="'+contribution.display_name+'" onchange="MetalLevelSelect.newContributionAmounts()"/>\
                <span class="checkmark"></span>\
              </label>\
            </div>\
          </div>\
        </div>\
        <div class="col-xs-6">\
          <div class="col-xs-3">\
            <input id="' + attrPrefix + '[display_name]" name="' + attrPrefix + '[display_name]" type="hidden" value="' + contribution["display_name"] + '" />\
            <input type="number" id="'+contribution.id+'" name="'+ attrPrefix +'[contribution_factor]" value="' + (contribution["contribution_factor"] * 100) + '" onchange="MetalLevelSelect.setInputSliderValue(this)" data-displayname="'+contribution.display_name+'" data-contribution-input="true">\
          </div>\
          <div class="col-xs-9">\
            <input type="range" min="0" max="100" value="' + (contribution["contribution_factor"] * 100) + '" step="5" class="slider" id="'+contribution.id+'" onchange="MetalLevelSelect.setNumberInputValue(this)" data-id="'+contribution.id+'" data-displayname="'+contribution.display_name+'">\
          </div>\
        </div>\
    </div>';
    element.insertBefore(div, element.children[-1] || null);
  }
}

function setNumberInputValue(element) {
  document.getElementById(element.dataset.id).value = element.value;
  newContributionAmounts();
}

function disableNewPlanYearButton() {
  let savePlanYearButton = document.getElementById('submitBenefitPackage') || document.getElementById('submitDentalBenefits');
  savePlanYearButton.classList.add('disabled');
  disableNewAddBenefitPackageButton();
  disableDentalBenefitPackage();
  preventSubmissionOnEnter();
}

function disableDentalBenefitPackage() {
  let addBenefitPackageButton = document.getElementById('dentalBenefits');
  if(addBenefitPackageButton) {
    addBenefitPackageButton.classList.add('disabled');
  }
}

function disableNewAddBenefitPackageButton() {
  let addBenefitPackageButton = document.getElementById('addBenefitPackage');
  addBenefitPackageButton.classList.add('disabled');
}

function preventSubmissionOnEnter() {
  let newBenefitPackageSubmit = document.getElementById('new_benefit_package') || document.getElementById('new_sponsored_benefits');
  newBenefitPackageSubmit.onkeypress = function(e) {
    let key = e.charCode || e.keyCode || 0;
    if (key == 13) {
      e.preventDefault();
    }
  }
}

function enableDentalBenefitPackage() {
  let addBenefitPackageButton = document.getElementById('dentalBenefits');
  if(addBenefitPackageButton) {
    addBenefitPackageButton.classList.remove('disabled')
  }
}

function enableNewAddBenefitPackageButton() {
  let addBenefitPackageButton = document.getElementById('addBenefitPackage');
  addBenefitPackageButton.classList.remove('disabled')
}

function enableNewPlanYearButton() {
  let savePlanYearButton = document.getElementById('submitBenefitPackage');
  savePlanYearButton.classList.remove('disabled');
  enableNewAddBenefitPackageButton()
  enableDentalBenefitPackage()
}

function setInputSliderValue(element) {
  document.querySelector("[data-id='"+element.id+"']").value = element.value;
  newContributionAmounts();
}

function showFormButtons() {
  let addBenefitPackage = document.getElementById('addBenefitPackage');
  if (addBenefitPackage)
    addBenefitPackage.classList.remove('hidden');
  let dentalBenefits = document.getElementById('dentalBenefits');
  if (dentalBenefits) {
    dentalBenefits.classList.remove('hidden')
  }
  let submitButton = document.getElementById('submitBenefitPackage') || document.getElementById('submitDentalBenefits');
  submitButton.classList.remove('hidden');
  let cancelButton = document.getElementById('cancelBenefitPackage') || document.querySelector('form .interaction-click-control-cancel');
  cancelButton.classList.remove('hidden');
}

function displayReferencePlanDetails(element, options) {
  if(!(element || options)) {
    return
  }
  let currentOptions = options || {};
  let planTitle = currentOptions.planTitle || element.dataset.planTitle;
  let metalLevel = currentOptions.metalLevel || element.dataset.planMetalLevel;
  let carrierName = currentOptions.carrierName || element.dataset.planCarrier;
  let planType = currentOptions.planType || element.dataset.planType;
  let referencePlanID = currentOptions.referencePlanID || element.id;
  let sponsoredBenefitId = currentOptions.sponsoredBenefitId;
  showFormButtons();

  document.getElementById('yourReferencePlanDetails').innerHTML = window.MetalLevelSelect_ReferencePlanDetailsShell;

  document.getElementById('referencePlanTitle').append(planTitle);
  document.getElementById('rpType').append(planType);
  document.getElementById('rpCarrier').append(carrierName);
  document.getElementById('rpMetalLevel').append(metalLevel);
  document.getElementById('rpNetwork').append('N/A');
  document.getElementById('planOfferingsTitle').innerHTML = '';
  document.getElementById('planOfferingsTitle').append(`Plan Offerings - ${planTitle} (${productsTotal})`)
  if (document.querySelector('input#sponsored_benefits_kind')) {
   calculateEmployerContributions(window.productOptionKind, referencePlanID, sponsoredBenefitId, "sponsored_benefits")
   calculateEmployeeCosts(window.productOptionKind, referencePlanID, sponsoredBenefitId, "sponsored_benefits")
 } else {
   calculateEmployerContributions(window.productOptionKind, referencePlanID, sponsoredBenefitId);
   calculateEmployeeCosts(window.productOptionKind, referencePlanID, sponsoredBenefitId);
 }
}

function viewSummary(element) {
  window.selectedSummaryTitle = element.dataset.planTitle;
  window.selectedReferencePlanID = element.dataset.planId;
  document.getElementById('viewSummaryTitle').innerHTML =  window.selectedSummaryTitle;
  let query_address = '/benefit_sponsors/benefit_sponsorships/'+window.selectedBenefitSponsorsID+'/benefit_applications/'+window.selectedBenefitApplicationID+'/benefit_packages/reference_product_summary?reference_plan_id='+window.selectedReferencePlanID;
  fetch(query_address)
    .then((res)=> res.json())
    .then((data)=> {
      data[1].map((s)=> {
      document.getElementById('sbcLink').setAttribute('href', data[2])
      let tr = document.createElement('tr');
      let tbody = document.getElementById('modalSummaryData');
      tr.innerHTML = '<td style="background-color:#f5f5f5">' + s.visit_type + '</td><td>' + s.copay_in_network_tier_1 + '</td><td>' + s.co_insurance_in_network_tier_1 + '</td>';
        tbody.insertBefore(tr, tbody.children[-1] || null);
      });
    })
    .then(window.$('#viewSummaryModal').modal('show'));
    window.showLess = false;
}

function showMoreDetails() {
  if (window.showLess) {
    document.getElementById('modalSummaryData').innerHTML = '';
    fetch('/benefit_sponsors/benefit_sponsorships/'+window.selectedBenefitSponsorsID+'/benefit_applications/'+window.selectedBenefitApplicationID+'/benefit_packages/reference_product_summary?reference_plan_id='+window.selectedReferencePlanID)
      .then((res)=> res.json())
      .then((data)=> {
        data[1].map((s)=> {
        document.getElementById('sbcLink').setAttribute('href', data[2])
        let tr = document.createElement('tr');
        let tbody = document.getElementById('modalSummaryData');
        tr.innerHTML = '<td style="background-color:#f5f5f5">' + s.visit_type + '</td><td>' + s.copay_in_network_tier_1 + '</td><td>' + s.co_insurance_in_network_tier_1 + '</td>';
          tbody.insertBefore(tr, tbody.children[-1] || null);
        });
      })
      .then(document.getElementById('btnMoreDetails').innerHTML = "More Details")
      window.showLess = false;
  } else {
    fetch('/benefit_sponsors/benefit_sponsorships/'+window.selectedBenefitSponsorsID+'/benefit_applications/'+window.selectedBenefitApplicationID+'/benefit_packages/reference_product_summary?reference_plan_id='+window.selectedReferencePlanID+'&details=details')
      .then((res)=> res.json())
      .then((data)=> {
        data[1].map((s)=> {
        let tr = document.createElement('tr');
        let tbody = document.getElementById('modalSummaryData');
        tr.innerHTML = '<td style="background-color:#f5f5f5">' + s.visit_type + '</td><td>' + s.copay_in_network_tier_1 + '</td><td>' + s.co_insurance_in_network_tier_1 + '</td>';
          tbody.insertBefore(tr, tbody.children[-1] || null);
        })
      })
      .then(document.getElementById('btnMoreDetails').innerHTML = "Fewer Details");
      window.showLess = true;
      }
}

function setTempCL() {
  let myLevels = localStorage.getItem("contributionLevels");
  window.selectedTitle = localStorage.getItem("title");

  if (myLevels) {
    let contributions = {};
    if (myLevels)
      contributions = JSON.parse(myLevels);
    else
      contributions = window.tempContributionValues;

    window.setTimeout(function() {
      let employee = document.querySelectorAll("[data-displayname='Employee']");
      let spouse = document.querySelectorAll("[data-displayname='Spouse']");
      let domesticPartner = document.querySelectorAll("[data-displayname='Domestic Partner']");
      let childUnder26 = document.querySelectorAll("[data-displayname='Child Under 26']");
      let employeeOnly = document.querySelectorAll("[data-displayname='Employee Only']");
      let family = document.querySelectorAll("[data-displayname='Family']");

      if (window.selectedTitle == "ONE CARRIER") {
        employee[1].value = contributions.eeContribution;
        employee[2].value = contributions.eeContribution;
        spouse[1].value = contributions.spouse;
        spouse[2].value = contributions.spouse;
        domesticPartner[1].value = contributions.domesticPartner;
        domesticPartner[2].value = contributions.domesticPartner;
        childUnder26[1].value = contributions.childUnder26;
        childUnder26[2].value = contributions.childUnder26;
      }

      if (window.selectedTitle == "ONE LEVEL") {
        employee[1].value = contributions.eeContribution;
        employee[2].value = contributions.eeContribution;
        spouse[1].value = contributions.spouse;
        spouse[2].value = contributions.spouse;
        domesticPartner[1].value = contributions.domesticPartner;
        domesticPartner[2].value = contributions.domesticPartner;
        childUnder26[1].value = contributions.childUnder26;
        childUnder26[2].value = contributions.childUnder26;
      }

      if (window.selectedTitle == "ONE PLAN") {
        employeeOnly[1].value = contributions.employeeOnly;
        employeeOnly[2].value = contributions.employeeOnly;
        family[1].value = contributions.familyOnly;
        family[2].value = contributions.familyOnly;
      }

    },500)
  }
}

function selectDefaultReferencePlan() {
    setTimeout(function() {
      let input = document.querySelectorAll('.reference-plans')[0].querySelector('input');
      input.click();
      let myplans = document.querySelector('#yourPlans');
      myplans.onmouseover = function() {
        myplans.click()
        document.getElementById('new_benefit_package').click()
      }
      let contributions = document.querySelector('#yourSponsorContributions');
      contributions.onmouseover = function() {
        contributions.click()
        document.getElementById('new_benefit_package').click()
      }
    },300);
  }


export const MetalLevelSelect = {
  radioSelected: radioSelected,
  getPlanInfo: getPlanInfo,
  newContributionAmounts: newContributionAmounts,
  setNumberInputValue: setNumberInputValue,
  disableNewAddBenefitPackageButton: disableNewAddBenefitPackageButton,
  disableDentalBenefitPackage: disableDentalBenefitPackage,
  disableNewPlanYearButton: disableNewPlanYearButton,
  enableDentalBenefitPackage: enableDentalBenefitPackage,
  enableNewAddBenefitPackageButton: enableNewAddBenefitPackageButton,
  enableNewPlanYearButton: enableNewPlanYearButton,
  setInputSliderValue: setInputSliderValue,
  viewSummary: viewSummary,
  showMoreDetails: showMoreDetails
}
