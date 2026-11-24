// Prevents DataTables controls from being duplicated when the browser's back
// button returns to a page that has a datatable on it.
//
// When you navigate away from a page, Turbolinks caches a clone of the live DOM
// and replays it -- scripts included -- when you come back. By then the live DOM
// holds the markup DataTables generated (the wrapper with the Copy/Excel/CSV/
// Print buttons, the length menu, the info line and the pagination), so the
// replayed initializer runs against a table that already looks initialized and
// builds a second set of those controls inside the first. DataTables cannot
// catch this on its own: its re-initialization guard compares table nodes, and
// the restored table is a clone of the original node rather than the node it
// knows about, so it treats the call as a brand new table.
//
// Destroying the tables before the snapshot is taken means only the bare <table>
// is cached, and the replayed initializer builds exactly one set of controls.
// turbolinks:before-cache fires immediately before Turbolinks clones the
// document, and the page is being replaced at that point, so the teardown is
// never visible to the user.
(function () {
  'use strict';

  function destroyDataTablesBeforeCache() {
    var $ = window.jQuery;

    if (!$ || !$.fn || !$.fn.dataTable || !$.fn.dataTable.tables) { return; }

    $.each($.fn.dataTable.tables(), function (_index, table) {
      try {
        $(table).DataTable().destroy();
      } catch (e) {
        // A table that is still initializing can raise here. Leaving that one
        // table in the snapshot is better than skipping the teardown of the
        // tables that come after it.
      }
    });
  }

  document.addEventListener('turbolinks:before-cache', destroyDataTablesBeforeCache);
})();
