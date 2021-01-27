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

function runGlossary() {
  if ($('.run-glossary').length) {
    var terms = [
      {
        "term": "Deductible",
        "description": "The amount you pay for covered health care services before your insurance plan starts to pay. With a $2,000 deductible, for example, you pay the first $2,000 of covered services yourself."
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
          var termRegex    = new RegExp("\\b(" + term.term + "[s]?)\\b", "gi");
          var popoverRegex = new RegExp("(<span class=\"glossary\".+?<\/span>)");
          var description  = term.description;
          var newElement   = "";
          $(matchingEl).html().toString().split(popoverRegex).forEach(function(text){
            // if a matching term has not yet been given a popover, replace it with the popover element
            if (!text.includes("class=\"glossary\"")) {
              newElement += text.replace(termRegex, '<span class="glossary" data-toggle="popover" data-placement="auto top" data-trigger="click focus" data-boundary="window" data-fallbackPlacement="flip" data-html="true" data-content="' + description + '" data-title="' + term.term + '<button data-dismiss=\'modal\' type=\'button\' class=\'close\' aria-label=\'Close\' onclick=\'hideGlossaryPopovers()\'></button>">$1</span>');
            }
            else {
              // if the term has already been given a popover, do not search it again
              newElement += text;
            }
            $(matchingEl).html(newElement);
          });
        });
    });
    $('[data-toggle="popover"]').popover();

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