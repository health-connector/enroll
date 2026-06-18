// page:change accounts for turbolinks affecting JS on document ready
// ajax:success accounts for glossary terms in consumer forms after document ready
// Rails 5 event: 'turbolinks:load' instead of 'page:change'
$(document).on("turbolinks:load ajax:success", function() {
  runGlossary();

  // Added for partials loaded after turbolinks load
  $('.close-2').click(function(e){
    $(document).ajaxComplete(function() {
      runGlossary();
    });
  });
});

/**
 * Replaces glossary terms with popover spans using word-boundary matching
 * Handles optional trailing 's' for plurals without RegExp
 * @param {string} text - The text to search
 * @param {string} term - The glossary term to find
 * @param {string} replacement - The HTML replacement for matched terms
 * @returns {string} Text with glossary terms replaced
 */
function replaceGlossaryTerm(text, term, replacement) {
    var result = '';
    var lowerTerm = term.toLowerCase();
    var lowerText = text.toLowerCase();
    var lastIndex = 0;
    var searchIndex = 0;
    
    while ((searchIndex = lowerText.indexOf(lowerTerm, searchIndex)) !== -1) {
        var endIndex = searchIndex + term.length;
        var matchesPlural = false;
        
        // Check for optional trailing 's' for plurals
        if (endIndex < text.length && lowerText[endIndex] === 's') {
            // Check if 's' is a word character boundary (part of plural)
            var nextCharIndex = endIndex + 1;
            var nextCharValid = nextCharIndex >= text.length || /\s|[^a-zA-Z0-9]/.test(text[nextCharIndex]);
            if (nextCharValid) {
                matchesPlural = true;
                endIndex++;
            }
        }
        
        // Check word boundary before match
        var isWordBoundaryBefore = searchIndex === 0 || /\s|[^a-zA-Z0-9]/.test(text[searchIndex - 1]);
        
        // Check word boundary after match (or after plural 's')
        var charAfterMatch = endIndex < text.length ? text[endIndex] : '';
        var isWordBoundaryAfter = endIndex === text.length || /\s|[^a-zA-Z0-9]/.test(charAfterMatch);
        
        if (isWordBoundaryBefore && isWordBoundaryAfter) {
            result += text.substring(lastIndex, searchIndex) + replacement;
            lastIndex = endIndex;
        }
        
        searchIndex = endIndex;
    }
    
    result += text.substring(lastIndex);
    return result;
}

function runGlossary() {
  if ($('.run-glossary').length) {
    var terms = [
      {
        "term": "Deductible",
        "description": "Your annual deductible is the amount you must pay for health care services before your health insurance company will start paying benefits. For example, if your deductible is $1,000, your health insurance company won’t pay benefits until you’ve paid $1,000 for certain health care services. The deductible may not apply to all services."
      }
    ]

    // this allows the :contains selector to be case insensitive
    $.expr[":"].contains = $.expr.createPseudo(function (arg) {
      return function (elem) {
        return $(elem).text().toLowerCase().indexOf(arg.toLowerCase()) >= 0;
      };
    });
    $(terms).each(function(i, term) {
        // finds the first instance of the term on the page
        // var matchingEl = $('.run-glossary:contains(' + term.term + ')').first();
        // if (matchingEl.length) {
        // finds every instance of the term on the page
        $('.run-glossary:contains(' + term.term + ')').each(function(i, matchingEl) {
          // matches the exact or plural term
          var popoverRegex = new RegExp("(<span class=\"glossary\".+?<\/span>)");
          var description  = term.description;
          var newElement   = "";
          var popoverHtml  = '<span class="glossary" data-toggle="popover" data-placement="auto top" data-trigger="click focus" data-boundary="window" data-fallbackPlacement="flip" data-html="true" data-content="' + description + '" data-title="' + term.term + '<button data-dismiss=\'modal\' type=\'button\' class=\'close\' aria-label=\'Close\' onclick=\'hideGlossaryPopovers()\'></button>">' + term.term + '</span>';
          $(matchingEl).html().toString().split(popoverRegex).forEach(function(text){
            // if a matching term has not yet been given a popover, replace it with the popover element
            if (!text.includes("class=\"glossary\"")) {
              newElement += replaceGlossaryTerm(text, term.term, popoverHtml);
            }
            else {
              // if the term has already been given a popover, do not search it again
              newElement += text;
            }
            $(matchingEl).html(newElement);
          });
        });
    });
    if( $('#referencePlans').length > 0 ) {
      $('[data-toggle="popover"]').popover({container: '#referencePlans'});
    }
    else if ( $('.plan-type-filters').length > 0 ) {
      $('[data-toggle="popover"]').popover({container: '.plan-type-filters', placement: 'left'});
    }
    else if ( $('.reference-plans').length > 0 ) {
      $('[data-toggle="popover"]').popover({container: '.reference-plans'});
    }
    else if ( $('.enrollment-tile').length > 0 ) {
      $('[data-toggle="popover"]').popover({container: '.enrollment-tile'});
    }
    else {
      $('[data-toggle="popover"]').popover();
    }

    // Because of the change to popover on click instead of hover, you need to
    // manually close each popover. This will close others if you click to open one
    // or click outside of a popover.

    $(document).click(function(e){
      if (e.target.className == 'glossary') {
        e.preventDefault();
        $('.glossary').not($(e.target)).popover('hide');
      }
      else if (!$(e.target).parents('.popover').length) {
        $('.glossary').popover('hide');
      }
    });
  }
}


function hideGlossaryPopovers() {
  $('.glossary').popover('hide');
}
