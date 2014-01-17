/*global $, root_url, static_url, tuner_id, tuner_number */
$.cookie.defaults.path = '/';
$.cookie.defaults.expires = 1000;
var tuner_map_data = [];

// Fluid layout doesn't seem to support 100% height; manually set it
function adjust_height() {
  "use strict";
  var srl_heights, cth_heights;

  $('.fullheight').height($(window).height());

  srl_heights = $('#tvdx-tabs').height() + $('#time-frame').height()
              + $('#sort-by').height() + $('#distance-units').height() + 11;
  $('#stations-rx-list').height($('.fullheight').height() - srl_heights);

  cth_heights = $('#tvdx-tabs').height() + $('#channel-bands').height()
              + $('#channel-sort-by').height()
              + $('#graph-time-range').height() + 11;
  $('#decodeable').height($('.fullheight').height() - cth_heights);
}


function restore_radio_button(category, default_value) {
  "use strict";
  if ($.cookie(category) === undefined) {
    $('#' + category + ' [value="' + default_value + '"]').button('toggle');
  } else {
    $("#" + category + " .btn").each(function () {
      if ($(this).attr('value') === $.cookie(category)) {
        $(this).button('toggle');
      }
    });
  }
}


function restore_checkbox(category, value) {
  "use strict";
  if ($.cookie(value) === undefined || $.cookie(value) === 'true') {
    $('#' + category + ' [value="' + value + '"]').button('toggle');
  }
}


// set buttons based on previously chosen selections saved to cookies
// or set default if there are is no cookie
function restore_saved() {
  "use strict";
  restore_radio_button('time-frame', "last-24-hours");
  restore_radio_button('sort-by', "distance");
  restore_radio_button('distance-units', 'miles');
  restore_checkbox('channel-bands', "vhf-low");
  restore_checkbox('channel-bands', "vhf-high");
  restore_checkbox('channel-bands', "uhf");
  restore_checkbox('channel-bands', "uhf-oob");
  restore_radio_button('channel-sort-by', "rf-channel");
  restore_radio_button('graph-time-range', "hourly");
  restore_radio_button('decodeable', "both");
}


// from http://jsfiddle.net/dFNva/1/
function sort_by(field, reverse, primer) {
  "use strict";
  var key;
  if (primer === Date) {
    key = function (x) { return new Date(x[field]); };
  } else {
    key = function (x) { return primer ? primer(x[field]) : x[field]; };
  }

  return function (a, b) {
    var A = key(a), B = key(b);
    return ((A < B) ? -1 : ((A > B) ? 1 : 0)) * [-1, 1][+!!reverse];
  };
}


function update_stations_received(sort_val, distance_units) {
  "use strict";
  // sort data
  var field = 'miles', asc = true, primer = parseInt, dx, height;
  // passed sort_val for sort-by click handler since .active isn't set until
  // after button is clicked
  sort_val = sort_val || $('#sort-by .active').attr('value');
  distance_units = distance_units || $('#distance-units .active').attr('value');
  if (sort_val === 'distance') {
    field = 'miles'; asc = false;
  }
  if (sort_val === 'rf-channel') {
    field = 'rf_channel'; asc = true;
  }
  if (sort_val === 'virtual-channel') {
    field = 'virtual_channel'; asc = true;
  }
  if (sort_val === 'time-received') {
    field = 'last_in'; asc = false; primer = Date;
  }
  if (sort_val === 'azimuth') {
    field = 'azimuth'; asc = true;
  }
  if (sort_val === 'callsign') {
    field = 'callsign'; asc = true; primer = undefined;
  }
  tuner_map_data.markers.sort(sort_by(field, asc, primer));

  // remove all list times in stations received list, then update it
  $("#stations-received-ul").empty();
  $.each(tuner_map_data.markers, function (index, val){
    if (distance_units === 'miles') {
      dx = val.miles + ' miles<br>';
      height = parseInt(parseFloat(val.rcamsl.split(' ')[0]) * 3.2808) + ' ft.';
    } else {
      dx = parseInt( val.miles * 1.609344 * 10) / 10 + ' km<br>'
      height = val.rcamsl;
    }
    $("#stations-received-ul").append(
         '<li class="sr-list">'
       + val.callsign
       + '<a href=' + root_url + '/signal_graph/' + tuner_id + '/' + tuner_number + '/' + val.callsign + '> Graphs</a><br>'
       + 'RF channel ' + val.rf_channel + '<br>'
       + 'Virtual channel ' + val.virtual_channel + '<br>'
       + val.city_state + '<br>'
       + 'ERP ' + val.erp + '<br>'
       + 'RCASML ' + height + '<br>'
       + 'Azimuth ' + val.azimuth + '&deg;<br>' 
       + 'Distance ' + dx + '<hr>'
       + "</li>");
  });
}


function update_map() {
  "use strict";
}


function update_page() {
  "use strict";
  update_stations_received();
  update_map();
}


// adjust height when channels tab is selected so decodeable section is
// correct size
$('#tvdx-tabs a[href="#tabs-stations-rx"]').click(function (e) {
  "use strict";
  e.preventDefault();
  $(this).tab('show');
});
$('#tvdx-tabs a[href="#tabs-stations-rx"]').on('shown.bs.tab', function () {
  "use strict";
  adjust_height();
});

// adjust height when stations tab is selected so stations received section is
// correct size
$('#tvdx-tabs a[href="#tabs-channel"]').click(function (e) {
  "use strict";
  e.preventDefault();
  $(this).tab('show');
});
$('#tvdx-tabs a[href="#tabs-channel"]').on('shown.bs.tab', function () {
  "use strict";
  adjust_height();
});


// button click event handelers
$("#time-frame .btn").click(function () {
  "use strict";
  $.cookie('time-frame', $(this).attr('value'));
});
$("#sort-by .btn").click(function () {
  "use strict";
  $.cookie('sort-by', $(this).attr('value'));
  update_stations_received($(this).attr('value'));
});
$("#distance-units .btn").click(function() {
  "use strict";
  $.cookie('distance-units', $(this).attr('value'));
  update_stations_received($("#sort-by .active").attr('value'),
                           $(this).attr('value'));
});
$('#channel-bands .btn').click(function() {
  "use strict";
  // cookie for each channel-band
  $.cookie($(this).attr('value'),! $('#channel-bands [value='
                                  +  $(this).attr('value')
                                  +  '] input').prop('checked'));
});
$("#channel-sort-by .btn").click(function() {
  "use strict";
  $.cookie('channel-sort-by', $(this).attr('value'));
});
$("#graph-time-range .btn").click(function () {
  "use strict";
  $.cookie('graph-time-range', $(this).attr('value'));
});
$("#decodeable .btn").click(function () {
  "use strict";
  $.cookie('decodeable', $(this).attr('value'));
});


adjust_height();
$('.btn').button();
// set buttons based on previously chosen selections saved to cookies
restore_saved();

var first_data_xhr =
  $.getJSON(root_url + "/tuner_map_data/" + tuner_id + "/" + tuner_number,
            function(tmd) { "use strict"; tuner_map_data = tmd; });
var gmap_xhr =
  $.getScript(static_url+'/gmap3.min.js',
              function () { "use strict"; $('#map-container').gmap3(); });
$.when(first_data_xhr, gmap_xhr).done(update_page);


// top-level functions
$(window).resize(adjust_height);
