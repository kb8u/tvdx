// Fluid layout doesn't seem to support 100% height; manually set it
adjust_height = function(){
  $('.fullheight').height($(window).height());

  other_srl_heights = $('#tvdx-tabs').height() + $('#time-frame').height()
                    + $('#sort-by').height() + $('#distance-units').height()+11
  $('#stations-rx-list').height($('.fullheight').height() - other_srl_heights)

  other_cth_heights = $('#tvdx-tabs').height() + $('#channel-bands').height()
                    + $('#channel-sort-by').height()
                    + $('#graph-time-range').height() + 11
  $('#modulation-buttons').height($('.fullheight').height()-other_cth_heights)
}

$(window).resize(adjust_height)
$(document).ready(adjust_height)

// adjust height when channels tab is selected so modulation section is
// correct size
$('#tvdx-tabs a[href="#tabs-stations-rx"]').click(function (e) {
  e.preventDefault()
  $(this).tab('show')
})
$('#tvdx-tabs a[href="#tabs-stations-rx"]').on('shown.bs.tab', function (e) {
  adjust_height()
})
$('#tvdx-tabs a[href="#tabs-channel"]').click(function (e) {
  e.preventDefault()
  $(this).tab('show')
})
$('#tvdx-tabs a[href="#tabs-channel"]').on('shown.bs.tab', function (e) {
  adjust_height()
})
