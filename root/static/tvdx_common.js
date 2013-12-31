// Fluid layout doesn't seem to support 100% height; manually set it
$(window).resize(function(){
  $('.fullheight').height($(window).height());
  $('#stations-rx-list').height(
    $('.fullheight').height()
      - $('#tvdx-tabs').height()
      - $('#time-frame').height()
      - $('#sort-by').height()
      - $('#distance-units').height()-6);
})
$(window).resize();

$(document).ready(function(){
  $('.fullheight').height($(window).height());
})

