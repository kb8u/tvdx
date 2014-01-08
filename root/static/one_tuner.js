$.cookie.defaults.path = '/'

// Fluid layout doesn't seem to support 100% height; manually set it
function adjust_height() {
  $('.fullheight').height($(window).height());

  other_srl_heights = $('#tvdx-tabs').height() + $('#time-frame').height()
                    + $('#sort-by').height() + $('#distance-units').height()+11
  $('#stations-rx-list').height($('.fullheight').height() - other_srl_heights)

  other_cth_heights = $('#tvdx-tabs').height() + $('#channel-bands').height()
                    + $('#channel-sort-by').height()
                    + $('#graph-time-range').height() + 11
  $('#modulation-buttons').height($('.fullheight').height()-other_cth_heights)
}


function update_page(latest,status_code,xhr) {
  if (status_code != "success") { return }
  // remove all list itmes in stations received list, then update it
  $("#stations-received-ul").empty();
  $.each(latest['markers'],function(index,val){
    $("#stations-received-ul").append("<li>"+val['callsign'])+"</li>"
  })
}


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


// button click event handelers
$("#time-frame .btn").click(function() {
  console.log("time-frame value ",$(this).attr('value'))
  $.cookie('time-frame', $(this).attr('value'))
})

$("#sort-by .btn").click(function() {
  $.cookie('sort-by', $(this).attr('value'))
})

$("#distance-units .btn").click(function() {
  $.cookie('distance-units', $(this).attr('value'))
})

// cookie for each channel-band
$('#channel-bands .btn').click(function() {
  $.cookie($(this).attr('value'),! $('#channel-bands [value='
                                  +  $(this).attr('value')
                                  +  '] input').prop('checked'))
})

$("#channel-sort-by .btn").click(function() {
  $.cookie('channel-sort-by', $(this).attr('value'))
})

$("#graph-time-range .btn").click(function() {
  $.cookie('graph-time-range', $(this).attr('value'))
})

// cookie for each modulation
$("#modulation-buttons .btn").click(function() {
  $.cookie($(this).attr('value'),! $('#modulation-buttons [value='
                                  +  $(this).attr('value')
                                  +  '] input').prop('checked'))
})


// top-level functions
$(window).resize(adjust_height)
$(document).ready(function() {
  adjust_height();
  $('.btn').button()
  // set buttons based on previously chosen selections saved to cookies
  // cookie code goes here...
  $('#map-container').gmap3();
  $.getJSON(root_url + "/tuner_map_data/" + tuner_id + "/" + tuner_number,
            function(latest,result,xhr){ update_page(latest,result,xhr) })
})
