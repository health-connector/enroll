import "core-js/";
import { calculateEmployerContributions, calculateEmployeeCosts } from "./benefit_application";

function enableNewAddBenefitPackageButton() {
  var addBenefitPackageButton = document.getElementById('addBenefitPackage');
  if (addBenefitPackageButton)
    addBenefitPackageButton.classList.remove('disabled');
}

function disableNewAddBenefitPackageButton() {
  var addBenefitPackageButton = document.getElementById('addBenefitPackage');
  if (addBenefitPackageButton)
    addBenefitPackageButton.classList.add('disabled');
}

function disableDentalBenefitPackage() {
  var addBenefitPackageButton = document.getElementById('dentalBenefits');
  if (addBenefitPackageButton)
    addBenefitPackageButton.classList.add('disabled');
}

function enableDentalBenefitPackage() {
  var addBenefitPackageButton = document.getElementById('dentalBenefits');
  if (addBenefitPackageButton)
    addBenefitPackageButton.classList.remove('disabled');
}

function getPlanInfo(element) {
  if (element.tagName != 'INPUT') {
    element = element.querySelector('input[type=radio][data-name]');
  }
  var selectedRadio = element.value;
  var selectedName = element.dataset.name;
  window.filteredProducts = window.planOptions[window.productOptionKind][selectedName];
  productsTotal = filteredProducts.length;
  populateReferencePlans(window.filteredProducts);
  setTempCL();
}

function radioSelected(element) {
  setCircle(element);
  disableNewPlanYearButton();
  // Store radio title to localStorage
  window.selectedTitle = element.querySelector('a').innerText;
  localStorage.setItem("title",selectedTitle);
}

function viewSummary(element) {
  window.selectedSummaryTitle = element.dataset.planTitle;
  window.selectedReferencePlanID = element.dataset.planId;
  document.getElementById('viewSummaryTitle').innerHTML = selectedSummaryTitle;
  var query_address = '/benefit_sponsors/benefit_sponsorships/'+window.selectedBenefitSponsorsID+'/benefit_applications/'+window.selectedBenefitApplicationID+'/benefit_packages/reference_product_summary?reference_plan_id='+window.selectedReferencePlanID;
  fetch(query_address)
    .then((res)=> res.json())
    .then((data)=> {
      data[1].map((s)=> {
      document.getElementById('sbcLink').setAttribute('href', data[2])
      var tr = document.createElement('tr');
      var tbody = document.getElementById('modalSummaryData');
      tr.innerHTML = `<td style="background-color:#f5f5f5">${s.visit_type}</td><td>${s.copay_in_network_tier_1}</td><td>${s.co_insurance_in_network_tier_1}</td>`;
      tbody.appendChild(tr)
      });
    })
    .then(window.$('#viewSummaryModal').modal('show'));
    window.showLess = false;
}

function showMoreDetails() {
  if (window.showLess) {
    document.getElementById('modalSummaryData').innerHTML = '';
    fetch('/benefit_sponsors/benefit_sponsorships/'+window.selectedBenefitSponsorsID+'/benefit_applications/'+window.selectedBenefitApplicationID+'/benefit_packages/reference_product_summary?reference_plan_id='+window.selectedReferencePlanID)
      .then(function(res) { return res.json() })
      .then(function(data) {
        data[1].map(function(s) {
          document.getElementById('sbcLink').setAttribute('href', data[2]);
          var tr = document.createElement('tr');
          var tbody = document.getElementById('modalSummaryData');
          tr.innerHTML = '<td style="background-color:#f5f5f5">' + s.visit_type + '</td><td>' + s.copay_in_network_tier_1 + '</td><td>' + s.co_insurance_in_network_tier_1 + '</td>';
          tbody.insertBefore(tr, tbody.children[-1] || null);
        })
      })
      .then(document.getElementById('btnMoreDetails').innerHTML = "More Details");
      window.showLess = false;
  } else {
    fetch('/benefit_sponsors/benefit_sponsorships/' + window.selectedBenefitSponsorsID + '/benefit_applications/' + window.selectedBenefitApplicationID + '/benefit_packages/reference_product_summary?reference_plan_id=' + window.selectedReferencePlanID + '&details=details')
      .then(function(res) { return res.json() })
      .then(function(data) {
        data[1].map(function(s) {
          var tr = document.createElement('tr');
          var tbody = document.getElementById('modalSummaryData');
          tr.innerHTML = '<td style="background-color:#f5f5f5">' + s.visit_type + '</td><td>' + s.copay_in_network_tier_1 + '</td><td>' + s.co_insurance_in_network_tier_1 + '</td>';
          tbody.insertBefore(tr, tbody.children[-1] || null);
        })
      })
      .then(document.getElementById('btnMoreDetails').innerHTML = "Fewer Details");
      window.showLess = true;
  }
}

function disableNewPlanYearButton() {
  var savePlanYearButton = document.getElementById('submitDentalBenefits');
  savePlanYearButton.classList.add('disabled');
  preventSubmissionOnEnter()
}

function enableNewPlanYearButton() {
  var savePlanYearButton = document.getElementById('submitDentalBenefits');
  savePlanYearButton.classList.remove('disabled');
}

function newContributionAmounts(element) {
  var contributionInputs = document.querySelectorAll("[data-contribution-input='true']")
  var contributionHandlers = document.querySelectorAll(".contribution_handler")

  contributionInputs.forEach(function(element) {
    switch (element.dataset.displayname) {
      case 'Employee':
        eeContribution = element.value;
        if (eeContribution > 0) {
          tempContributionValues.eeContribution = parseInt (eeContribution);
        }
      break;
      case 'Spouse':
        spouse = element.value;
        if (spouse > 0) {
          tempContributionValues.spouse = parseInt (spouse);
        }
      break;
      case 'Domestic Partner':
        domesticPartner = element.value;
        if (domesticPartner > 0) {
          tempContributionValues.domesticPartner = parseInt (domesticPartner);
        }
      break;
      case 'Child Under 26':
        childUnder26 = element.value;
        if (childUnder26 > 0) {
          tempContributionValues.childUnder26 = parseInt (childUnder26);
        }
      break;
    }

    tempLevels = JSON.stringify(tempContributionValues);
    localStorage.setItem("contributionLevels",tempLevels);
  })

  contributionHandlers.forEach(function(element) {
    switch (element.dataset.displayname) {
      case 'Employee':
        if(!(element.checked)) {
          eeContribution = 100
        }
      break;
      case 'Spouse':
        if(!(element.checked)) {
          spouse = 100
        }
      break;
      case 'Domestic Partner':
        if(!(element.checked)) {
          domesticPartner = 100
        }
      break;
      case 'Child Under 26':
        if(!(element.checked)) {
          childUnder26 = 100
        }
      break;
    }
  })

  if (document.getElementById('sponsored_benefits_is_new_benefit').value == "true") {
    if (eeContribution < erCL) {
      disableNewPlanYearButton()
    } else if (spouse < familyCL || domesticPartner < familyCL || childUnder26 < familyCL) {
      disableNewPlanYearButton()
    } else if (!(document.querySelectorAll(".reference-plans input[type='radio']:checked").length)) {
      disableNewPlanYearButton()
    } else {
      enableNewPlanYearButton()
    }
  }

  displayReferencePlanDetails(document.querySelector("input[name='sponsored_benefits[reference_plan_id]']:checked"));
}

function displayReferencePlanDetails(element, options) {
  if(!(element || options)) {
    return
  }

  options = options || {};
  var planTitle = options.planTitle || element.dataset.planTitle;
  var metalLevel = options.metalLevel || element.dataset.metalLevel;
  var carrierName = options.carrierName || element.dataset.carrierName;
  var planType = options.planType || element.dataset.planType;
  var referencePlanID = options.referencePlanID || element.value;
  var sponsoredBenefitId = options.sponsoredBenefitId;
  // showFormButtons();

  if (productsTotal === undefined){
    if (element) {
      var selectedName = element.dataset.carrierName;
      filteredProducts = planOptions[productOptionKind][selectedName];
      productsTotal = filteredProducts.length;
    }
  }

  document.getElementById('yourReferencePlanDetails').innerHTML = window.MetalLevelSelect_ReferencePlanDetailsShell;

  if (element.parentElement.classList.contains('edit_flow')) {
    document.getElementById('changeReferencePlan').classList.remove('hidden');
  }

  document.getElementById('referencePlanTitle').append(planTitle);
  document.getElementById('rpType').append(planType);
  document.getElementById('rpCarrier').append(carrierName);
  document.getElementById('rpMetalLevel').append(metalLevel);
  document.getElementById('rpNetwork').append('N/A');

  document.getElementById('planOfferingsTitle').innerHTML = '';
  document.getElementById('planOfferingsTitle').append(`Plan Offerings - ${planTitle} (${window.productsTotal})`)

  if (document.getElementById('referencePlanEditDisplay')) {
    document.getElementById('referencePlanEditDisplay').classList.add('hidden');
  }

  calculateEmployerContributions(window.productOptionKind, referencePlanID, sponsoredBenefitId, "sponsored_benefits")
  calculateEmployeeCosts(window.productOptionKind, referencePlanID, sponsoredBenefitId, "sponsored_benefits")
}

function preventSubmissionOnEnter() {
  document.getElementById('new_benefit_package').onkeypress = function(e) {
    var key = e.charCode || e.keyCode || 0;
    if (key == 13) {
       e.preventDefault();
    }
  }
}

function loadEmployeeCosts() {
  var table = document.getElementById('eeTableBody');

  table.querySelectorAll('tr').forEach(function(element) {
    element.remove()
  });

  var tr = document.createElement('tr')
  var estimate = window.employeeCostEstimate;
  var productOptionKind = 'single_product';
  var planOptions = window.planOptions;
  var element = document.querySelector("input[name='sponsored_benefits[reference_plan_id]']:checked");
  var selectedName = element.dataset.carrierName;
  var planTitle = element.dataset.planTitle;
  var filteredProducts = planOptions[productOptionKind][selectedName];

  document.getElementById('planOfferingsTitle').innerHTML = '';
  document.getElementById('planOfferingsTitle').append(`Plan Offerings - ${planTitle} (${filteredProducts.length})`)

  tr.innerHTML =
    `
    <td class="text-center">${estimate[0].name}</td>
    <td class="text-center">${estimate[0].dependent_count}</td>
    <td class="text-center">$ ${estimate[0].lowest_cost_estimate}</td>
    <td class="text-center">$ ${estimate[0].reference_estimate}</td>
    <td class="text-center">$ ${estimate[0].highest_cost_estimate}</td>
    `
  table.appendChild(tr)
}

function loadSingleProductSponsorContribution(element) {
  document.querySelectorAll("[id^='carrierProducts']").forEach(function(key) {
    key.classList.add("hidden")
  })
  document.getElementById("carrierProducts"+element.dataset.issuername).classList.remove('hidden')
  document.getElementById("referencePlans").classList.remove('hidden')
}

function setSliderInput(element) {
  document.querySelector(".slider-"+element.dataset.unitId).value = element.value;
}

function setNumberInput(element) {
  document.querySelector(".cl-input-"+element.dataset.unitId).value = element.value;
}

export const MetalLevelSelect = {
  disableDentalBenefitPackage: disableDentalBenefitPackage,
  enableNewAddBenefitPackageButton: enableNewAddBenefitPackageButton,
  disableNewAddBenefitPackageButton: disableNewAddBenefitPackageButton,
  disableNewPlanYearButton: disableNewPlanYearButton,
  enableNewPlanYearButton: enableNewPlanYearButton,
  enableDentalBenefitPackage: enableDentalBenefitPackage,
  displayReferencePlanDetails: displayReferencePlanDetails,
  getPlanInfo: getPlanInfo,
  loadEmployeeCosts: loadEmployeeCosts,
  newContributionAmounts: newContributionAmounts,
  radioSelected: radioSelected,
  setPlanOptionKind: setPlanOptionKind,
  showMoreDetails: showMoreDetails,
  viewSummary: viewSummary,
  preventSubmissionOnEnter: preventSubmissionOnEnter,
  loadSingleProductSponsorContribution: loadSingleProductSponsorContribution,
  setSliderInput: setSliderInput,
  setNumberInput: setNumberInput
};
