$(document).on('turbolinks:load', function() {
    $('.filter-form button[type="submit"]').on('click', function(event) {
        event.preventDefault();

        filterPlans();
    });

    $('#clear-filters').on('click', function() {
        $('.filter-form input[type="checkbox"]').prop('checked', false);
        $('.filter-form input[type="text"]').val('');

        filterPlans();
    });

    function filterPlans() {
        const planTypes = [];
        const pvpRatingAreas = [];
        const metalLevels = [];
        const searchPlan = $('input[name="search"]').val().toLowerCase();

        $('input[name="plan_type[]"]:checked').each(function() {
            planTypes.push($(this).val().toLowerCase());
        });

        $('input[name="pvp_rating_areas[]"]:checked').each(function() {
            pvpRatingAreas.push($(this).val().toLowerCase());
        });

        $('input[name="metal_level[]"]:checked').each(function() {
            metalLevels.push($(this).val().toLowerCase());
        });

        let visiblePlansCount = 0;

        $('tbody tr').each(function() {
            const planType = $(this).data('plan-type').toString().toLowerCase();
            const pvpAreas = $(this).data('pvp-areas').toString().toLowerCase();
            const metalLevel = $(this).data('metal-level').toLowerCase();
            const planId = $(this).data('plan-id').toLowerCase();
            const planName = $(this).data('plan-name').toLowerCase();

            let showRow = true;

            if (planTypes.length > 0 && !planTypes.some(pt => planType.includes(pt))) {
                showRow = false;
            }

            if (pvpRatingAreas.length > 0 && !pvpRatingAreas.includes(pvpAreas)) {
                showRow = false;
            }

            if (metalLevels.length > 0 && !metalLevels.includes(metalLevel)) {
                showRow = false;
            }

            if (searchPlan !== '' && !(planId.includes(searchPlan) || planName.includes(searchPlan))) {
                showRow = false;
            }

            if (showRow) {
                $(this).show();
                visiblePlansCount++;
            } else {
                $(this).hide();
            }
        });

        $('.plans-count').text(visiblePlansCount);
    }
});
