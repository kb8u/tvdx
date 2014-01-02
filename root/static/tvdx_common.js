// Fluid layout doesn't seem to support 100% height; manually set it
adjust_height = function(){
  $('.fullheight').height($(window).height());
  $('#stations-rx-list').height(
    $('.fullheight').height()
      - $('#tvdx-tabs').height()
      - $('#time-frame').height()
      - $('#sort-by').height()
      - $('#distance-units').height()-6);
  $('#modulation-buttons').height(
    $('.fullheight').height()
      - $('#tvdx-tabs').height()
      - $('#channel-bands').height()
      - $('#channel-sort-by').height()
      - $('#graph-time-range').height()-6);
}

$(window).resize(adjust_height);
$(document).ready(adjust_height);

// adjust height when channels tab is selected so modulation section is
// correct size
