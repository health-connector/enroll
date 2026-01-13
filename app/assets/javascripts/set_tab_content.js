window.set_tab_content = function(partial) {
 $('.flash').remove();
  $('#inbox > #tabContent').html(partial);
}

window.tab_id = function(tab_id) {
  $(tab_id).siblings().each(function(){
    $(this).removeClass('active');
  });
  $(tab_id).addClass('active');
}

window.setTabContent = function(partial) {
  $('.flash').remove();
  $('#myTabContent').html(partial);
}
