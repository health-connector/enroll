/**
 * Plan Comparison functionality for selecting and comparing benefit plans
 * Manages selection state and navigation to comparison view
 */

(function() {
  'use strict';

  // Track selected plans for comparison
  var selectedPlansForComparison = [];
  var MAX_PLANS_TO_COMPARE = 3;

  /**
   * Toggle plan selection for comparison
   * @param {HTMLInputElement} checkbox - The checkbox element that was toggled
   */
  window.toggleComparePlan = function(checkbox) {
    var planId = checkbox.dataset.planId;
    
    if (checkbox.checked) {
      // Check if we've reached the maximum number of plans
      if (selectedPlansForComparison.length >= MAX_PLANS_TO_COMPARE) {
        checkbox.checked = false;
        alert('You can only compare up to ' + MAX_PLANS_TO_COMPARE + ' plans at a time.');
        return;
      }
      // Add plan to comparison list
      if (!selectedPlansForComparison.includes(planId)) {
        selectedPlansForComparison.push(planId);
      }
    } else {
      // Remove plan from comparison list
      var index = selectedPlansForComparison.indexOf(planId);
      if (index > -1) {
        selectedPlansForComparison.splice(index, 1);
      }
    }
    
    // Update compare button visibility/state
    updateCompareButtonState();
  };

  /**
   * Update the state of the compare button based on selected plans
   * Enables button if at least 2 plans are selected, disables otherwise
   */
  window.updateCompareButtonState = function() {
    console.log('Selected ' + selectedPlansForComparison.length + ' plans for comparison:', selectedPlansForComparison);
    
    // Enable/disable compare button based on selection count
    var compareButton = document.getElementById('compareSelectedPlansButton');
    if (compareButton) {
      if (selectedPlansForComparison.length >= 2) {
        compareButton.disabled = false;
        compareButton.classList.remove('disabled');
      } else {
        compareButton.disabled = true;
        compareButton.classList.add('disabled');
      }
    }
  };

  /**
   * Navigate to the plan comparison page with selected plan IDs
   * Opens comparison in a modal via AJAX
   */
  window.compareSelectedPlans = function(event) {
    // Prevent default form submission
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    
    if (selectedPlansForComparison.length < 2) {
      alert('Please select at least 2 plans to compare.');
      return false;
    }
    
    // Get benefit sponsorship and application IDs from the page
    var selectedBenefitSponsorsID = window.selectedBenefitSponsorsID || '';
    var selectedBenefitApplicationID = window.selectedBenefitApplicationID || '';
    var selectedBenefitPackageID = window.selectedBenefitPackageID || '';
    
    if (!selectedBenefitApplicationID) {
      console.error('Missing benefit application ID');
      alert('Unable to load comparison. Please try again.');
      return false;
    }
    
    // Collect complete form data for benefit package configuration
    var formData = collectBenefitPackageFormData();
    formData.plans = selectedPlansForComparison.join(',');
    formData.benefit_application_id = selectedBenefitApplicationID;
    formData.benefit_package_id = selectedBenefitPackageID;
    
    // Build URL
    var compareUrl = '/benefit_sponsors/benefit_sponsorships/' + selectedBenefitSponsorsID + 
                     '/benefit_applications/' + selectedBenefitApplicationID + 
                     '/benefit_packages/' + selectedBenefitPackageID +
                     '/product_comparisons/new';
    
    // Show the modal
    var modal = $('#planComparisonModal');
    if (modal.length === 0) {
      console.error('Plan comparison modal not found');
      alert('Unable to display comparison. Please refresh the page.');
      return false;
    }
    
    // Show loading spinner
    modal.find('#comparisonLoadingSpinner').show();
    modal.find('#comparisonContent').html('');
    modal.modal('show');
    
    // Store comparison URL for export buttons
    modal.data('compareUrl', compareUrl);
    modal.data('plansParam', formData.plans);
    modal.data('benefitSponsorshipId', selectedBenefitSponsorsID);
    modal.data('benefitApplicationId', selectedBenefitApplicationID);
    modal.data('benefitPackageId', selectedBenefitPackageID);
    
    // Fetch comparison data via AJAX
    $.ajax({
      url: compareUrl,
      type: 'GET',
      data: formData,
      dataType: 'json',
      success: function(response) {
        modal.find('#comparisonLoadingSpinner').hide();
        if (response.success && response.html) {
          modal.find('#comparisonContent').html(response.html);
        } else {
          modal.find('#comparisonContent').html('<div class="alert alert-danger">Unable to load comparison data.</div>');
        }
      },
      error: function(xhr, status, error) {
        console.error('Error loading comparison:', error);
        modal.find('#comparisonLoadingSpinner').hide();
        modal.find('#comparisonContent').html(
          '<div class="alert alert-danger">' +
          'An error occurred while loading the comparison. Please try again.' +
          '</div>'
        );
      }
    });
    
    return false;
  };

  /**
   * Collect all benefit package form data from the page
   * @returns {Object} Form data for benefit package configuration
   */
  function collectBenefitPackageFormData() {
    var formData = {};
    
    // Get reference plan ID (selected radio button)
    var referencePlanInput = $('input[name="benefit_package[sponsored_benefits_attributes][0][reference_plan_id]"]:checked');
    if (referencePlanInput.length > 0) {
      formData.reference_plan_id = referencePlanInput.val();
    }
    
    // Get product package kind (stored in hidden input)
    var ppKind = $('#ppKind').val();
    if (ppKind) {
      formData.product_package_kind = ppKind;
    }
    
    // Get product option choice (the actual selected value - issuer name, metal level, or plan)
    var productOptionChoice = $('input.product_option_choice:checked').val();
    if (productOptionChoice) {
      formData.product_option_choice = productOptionChoice;
    }
    
    // Collect contribution levels
    var contributionLevels = {};
    $('input[name^="benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes]"]').each(function() {
      var input = $(this);
      var name = input.attr('name');
      
      // Parse the name to get index and field name
      // Example: benefit_package[sponsored_benefits_attributes][0][sponsor_contribution_attributes][contribution_levels_attributes][0][contribution_factor]
      var matches = name.match(/\[contribution_levels_attributes\]\[(\d+)\]\[(\w+)\]/);
      if (matches) {
        var index = matches[1];
        var fieldName = matches[2];
        
        if (!contributionLevels[index]) {
          contributionLevels[index] = {};
        }
        
        if (input.attr('type') === 'checkbox') {
          contributionLevels[index][fieldName] = input.is(':checked') ? '1' : '0';
        } else {
          contributionLevels[index][fieldName] = input.val();
        }
      }
    });
    
    // Add contribution levels to form data if any were collected
    if (Object.keys(contributionLevels).length > 0) {
      formData.contribution_levels = contributionLevels;
    }
    
    return formData;
  }

  /**
   * Get the current list of selected plan IDs
   * @returns {Array} Array of selected plan IDs
   */
  window.getSelectedPlansForComparison = function() {
    return selectedPlansForComparison.slice(); // Return a copy
  };

  /**
   * Clear all selected plans
   */
  window.clearSelectedPlans = function() {
    selectedPlansForComparison = [];
    // Uncheck all comparison checkboxes
    var checkboxes = document.querySelectorAll('.compare-plan-checkbox');
    checkboxes.forEach(function(cb) {
      cb.checked = false;
    });
    updateCompareButtonState();
  };

  /**
   * Initialize export button handlers when document is ready
   */
  $(document).ready(function() {
    // Export to PDF handler
    $(document).on('click', '#exportComparisonPDF', function() {
      var modal = $('#planComparisonModal');
      var benefitSponsorshipId = modal.data('benefitSponsorshipId');
      var benefitApplicationId = modal.data('benefitApplicationId');
      var benefitPackageId = modal.data('benefitPackageId');
      var plansParam = modal.data('plansParam');
      
      if (benefitSponsorshipId && benefitApplicationId && benefitPackageId && plansParam) {
        var exportUrl = '/benefit_sponsors/benefit_sponsorships/' + benefitSponsorshipId +
                       '/benefit_applications/' + benefitApplicationId +
                       '/benefit_packages/' + benefitPackageId +
                       '/product_comparisons/export?plans=' + plansParam;
        window.open(exportUrl, '_blank');
      }
    });

    // Export to CSV handler
    $(document).on('click', '#exportComparisonCSV', function() {
      var modal = $('#planComparisonModal');
      var benefitSponsorshipId = modal.data('benefitSponsorshipId');
      var benefitApplicationId = modal.data('benefitApplicationId');
      var benefitPackageId = modal.data('benefitPackageId');
      var plansParam = modal.data('plansParam');
      
      if (benefitSponsorshipId && benefitApplicationId && benefitPackageId && plansParam) {
        var exportUrl = '/benefit_sponsors/benefit_sponsorships/' + benefitSponsorshipId +
                       '/benefit_applications/' + benefitApplicationId +
                       '/benefit_packages/' + benefitPackageId +
                       '/product_comparisons/csv?plans=' + plansParam;
        window.location.href = exportUrl;
      }
    });
  });

})();
