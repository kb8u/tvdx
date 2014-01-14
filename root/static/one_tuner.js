$.cookie.defaults.path = '/'
$.cookie.defaults.expires = 1000

// Fluid layout doesn't seem to support 100% height; manually set it
function adjust_height() {
  $('.fullheight').height($(window).height());

  other_srl_heights = $('#tvdx-tabs').height() + $('#time-frame').height()
                    + $('#sort-by').height() + $('#distance-units').height()+11
  $('#stations-rx-list').height($('.fullheight').height() - other_srl_heights)

  other_cth_heights = $('#tvdx-tabs').height() + $('#channel-bands').height()
                    + $('#channel-sort-by').height()
                    + $('#graph-time-range').height() + 11
  $('#decodeable').height($('.fullheight').height()-other_cth_heights)
}


function restore_radio_button(category,default_value) {
  if ($.cookie(category) === undefined) {
    $('#'+category+' [value="'+default_value+'"]').button('toggle')
  }
  else {
    $("#"+category+" .btn").each(function() {
      if ($(this).attr('value') == $.cookie(category)) {
        $(this).button('toggle')
      }
    })
  }
}


function restore_checkbox(category,value) {
  if ($.cookie(value) === undefined || $.cookie(value) == 'true') {
    $('#'+category+' [value="'+value+'"]').button('toggle')
  }
}


// set buttons based on previously chosen selections saved to cookies
// or set default if there are is no cookie
function restore_saved() {
  restore_radio_button('time-frame',"last-24-hours")
  restore_radio_button('sort-by',"distance")
  restore_radio_button('distance-units','miles')
  restore_checkbox('channel-bands',"vhf-low")
  restore_checkbox('channel-bands',"vhf-high")
  restore_checkbox('channel-bands',"uhf")
  restore_checkbox('channel-bands',"uhf-oob")
  restore_radio_button('channel-sort-by',"rf-channel")
  restore_radio_button('graph-time-range',"hourly")
  restore_radio_button('decodeable',"both")
}


function update_page() {
  update_stations_received()
  update_map()
}


// from http://jsfiddle.net/dFNva/1/
function sort_by(field, reverse, primer) {
  var key = function (x) {return primer ? primer(x[field]) : x[field]};

  return function (a,b) {
    var A = key(a), B = key(b);
    return ( (A < B) ? -1 : ((A > B) ? 1 : 0) ) * [-1,1][+!!reverse];
  }
}


function update_stations_received(sort_val) {
  // sort data
  field = 'miles'
  asc = true
  primer = parseInt
  // passed sort_val for sort-by click handler since .active isn't set until
  // after button is clicked
  sort_val = sort_val ? sort_val : $('#sort-by .active').attr('value')
  if (sort_val == 'distance') { field = 'miles';asc=true }
  if (sort_val == 'rf-channel') { field = 'rf_channel';asc=true }
  if (sort_val == 'virtual-channel') { field = 'virtual_channel';asc=true }
  // add a primer function to convert date string to epoch
  if (sort_val == 'time-received') { field = 'last_in';asc=true;primer=undefined }
  if (sort_val == 'azimuth') { field = 'azimuth';asc=true }
  if (sort_val == 'callsign') { field = 'callsign';asc=true;primer=undefined }
  tuner_map_data['markers'].sort(sort_by(field,asc,primer))

  // remove all list itmes in stations received list, then update it
  $("#stations-received-ul").empty();
  $.each(tuner_map_data['markers'],function(index,val){
    $("#stations-received-ul").append("<li>"+val['callsign'])+"</li>"
  })
}


function update_map() {
}


// adjust height when channels tab is selected so decodeable section is
// correct size
$('#tvdx-tabs a[href="#tabs-stations-rx"]').click(function (e) {
  e.preventDefault()
  $(this).tab('show')
})
$('#tvdx-tabs a[href="#tabs-stations-rx"]').on('shown.bs.tab', function (e) {
  adjust_height()
})

// adjust height when stations tab is selected so stations received section is
// correct size
$('#tvdx-tabs a[href="#tabs-channel"]').click(function (e) {
  e.preventDefault()
  $(this).tab('show')
})
$('#tvdx-tabs a[href="#tabs-channel"]').on('shown.bs.tab', function (e) {
  adjust_height()
})


// button click event handelers
$("#time-frame .btn").click(function() {
  $.cookie('time-frame', $(this).attr('value'))
})
$("#sort-by .btn").click(function() {
  $.cookie('sort-by', $(this).attr('value'))
  update_stations_received($(this).attr('value'))
})
$("#distance-units .btn").click(function() {
  $.cookie('distance-units', $(this).attr('value'))
})
$('#channel-bands .btn').click(function() {
  // cookie for each channel-band
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
$("#decodeable .btn").click(function() {
  $.cookie('decodeable', $(this).attr('value'))
})


adjust_height();
$('.btn').button()
// set buttons based on previously chosen selections saved to cookies
restore_saved();

first_data_xhr =
  $.getJSON(root_url + "/tuner_map_data/" + tuner_id + "/" + tuner_number,
            function(tmd){ tuner_map_data = tmd})
gmap_xhr =
  $.getScript(static_url+'/gmap3.min.js',
              function(){$('#map-container').gmap3()})
$.when(first_data_xhr,gmap_xhr).done(update_page)


// top-level functions
$(window).resize(adjust_height)
