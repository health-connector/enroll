function getCostDetails(min,max,cost) {
  document.getElementById('employerCostTitle').textContent = '';
  document.getElementById('employerCostTitle').append(`Employer Lowest/Reference/Highest - $${min}/$${cost}/$${max}`);
}

function showCostDetails(cost,min,max) {
  document.getElementById('rpEstimatedMonthlyCost').textContent = '$ ' + cost;

  if (min == 'NaN') {
    min = "0.00"
  }

  if (max == 'NaN') {
    max = "0.00"
  }

  document.getElementById('rpMin').textContent = '$ ' + min;
  document.getElementById('rpMax').textContent = '$ ' + max;
  if (document.getElementById('estimatedEEMin')) {
    document.getElementById('estimatedEEMin').textContent = '$ ' + min;
  }
  if (document.getElementById('estimatedEEMax')) {
    document.getElementById('estimatedEEMax').textContent = '$ ' + max;
  }
  if (document.getElementById('estimatedERCost')) {
    document.getElementById('estimatedERCost').textContent = '$ ' + cost;
  }
  getCostDetails(min,max,cost)
}

function showEmployeeCostDetails(employees_cost) {
  var table = document.getElementById('eeTableBody');
  table.querySelectorAll('tr').forEach(function(element) {
    element.remove()
  });
  //modal = document.getElementById('modalInformation')
  //row = document.createElement('col-xs-12')
  //row.innerHTML = `Plan Offerings - <br/>Employer Lowest/Reference/Highest -`
  //modal.appendChild(row)

  for (var employee in employees_cost) {
    var tr = document.createElement('tr');
    estimate = employees_cost[employee];

    var tdName = document.createElement('td');
    tdName.className = 'text-center';
    tdName.textContent = estimate.name;

    var tdCount = document.createElement('td');
    tdCount.className = 'text-center';
    tdCount.textContent = estimate.dependent_count;

    var tdLowest = document.createElement('td');
    tdLowest.className = 'text-center';
    tdLowest.textContent = '$ ' + estimate.lowest_cost_estimate;

    var tdReference = document.createElement('td');
    tdReference.className = 'text-center';
    tdReference.textContent = '$ ' + estimate.reference_estimate;

    var tdHighest = document.createElement('td');
    tdHighest.className = 'text-center';
    tdHighest.textContent = '$ ' + estimate.highest_cost_estimate;

    tr.appendChild(tdName);
    tr.appendChild(tdCount);
    tr.appendChild(tdLowest);
    tr.appendChild(tdReference);
    tr.appendChild(tdHighest);

    table.appendChild(tr);
  }
}

// Function to toggle spinner visibility using the estimated-costs-shell class
function toggleSpinner(show) {
  const $shell = $('.estimated-costs-shell');
  if (!$shell.length) return;

  const $spinnerRow = $shell.find('.spinner-overlay'); // Find the spinner row within the shell
  if (!$spinnerRow.length) return;

  if (show) {
    $spinnerRow.removeClass('hidden');
  } else {
    $spinnerRow.addClass('hidden');
  }
}

function debounceRequest(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this, args = arguments;

    if (func === calculateEmployerContributionsImmediate) {
      toggleSpinner(true);
    }

		clearTimeout(timeout);
		timeout = setTimeout(function() {
			timeout = null;
			if (!immediate) func.apply(context, args);
		}, wait);
		if (immediate && !timeout) func.apply(context, args);
	};
}


function calculateEmployeeCostsImmediate(productOptionKind,referencePlanID, sponsoredBenefitId, referenceModel = "benefit_package")  {
  var thing = $("input[name^='"+referenceModel+"['").serializeArray();
  var submitData = {};
  for (item in thing) {
    submitData[thing[item].name] = thing[item].value;
  }
  // We have to append this afterwards because somehow, somewhere, there is an empty field corresponding
  // to product package kind.
  submitData[referenceModel] = {
    sponsored_benefits_attributes: { "0": { product_package_kind: productOptionKind,reference_plan_id: referencePlanID, id: sponsoredBenefitId } }
  };
  $.ajax({
    type: "GET",
    data: submitData,
    url: "calculate_employee_cost_details",
    success: function (d) {
      showEmployeeCostDetails(d);
    }
  });
}

const calculateEmployeeCosts = debounceRequest(calculateEmployeeCostsImmediate, 1000);

function calculateEmployerContributionsImmediate(productOptionKind,referencePlanID, sponsoredBenefitId, referenceModel = "benefit_package")  {
  var thing = $("input[name^='"+referenceModel+"['").serializeArray();
  var submitData = { };
  for (item in thing) {
    submitData[thing[item].name] = thing[item].value;
  }
  // We have to append this afterwards because somehow, somewhere, there is an empty field corresponding
  // to product package kind.
  submitData[referenceModel] = {
    sponsored_benefits_attributes: { "0": { product_package_kind: productOptionKind,reference_plan_id: referencePlanID, id: sponsoredBenefitId } }
  };
  $.ajax({
    type: "GET",
    data: submitData,
    url: "calculate_employer_contributions",
    success: function (d) {
      var eeMin = parseFloat(d["estimated_enrollee_minimum"]).toFixed(2);
      var eeCost = parseFloat(d["estimated_sponsor_exposure"]).toFixed(2);
      var eeMax = parseFloat(d["estimated_enrollee_maximum"]).toFixed(2);
      showCostDetails(eeCost,eeMin,eeMax)
      toggleSpinner(false);
    }
  });
}

const calculateEmployerContributions = debounceRequest(calculateEmployerContributionsImmediate, 1000);

module.exports = {
  calculateEmployerContributions : calculateEmployerContributions,
  calculateEmployeeCosts : calculateEmployeeCosts
};
