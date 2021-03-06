/*global $, google, StyledMarker, root_url, static_url, tuner_id, tuner_number, tmd_interval */
$.cookie.defaults.path = '/';
$.cookie.defaults.expires = 1000;
var tuner_map_data = [], tmd_interval;
var map_or_graph = '#stations-map';


// Fluid layout doesn't seem to support 100% height; manually set it
function adjust_height() {
  "use strict";
  var srl_heights, cth_heights;

  // reset configuration options if resizing to large
  if (   ! $('#stations-config').is(':visible')
      && $('#btn-config').text() === 'Show Configure') {
    $('#time-frame').show();
    $('#sort-by').show();
    $('#distance-units').show();
    $('#stations-rx-list').removeClass('btn-group-box-top');
    $('#btn-config').text('Hide Configure');
  }

  $('.fullheight').height($(window).height());

  srl_heights = $('#tvdx-tabs').height();

  if (! $('#stations-config').is(':visible')) {
    srl_heights += $('#time-frame').height();
    srl_heights += $('#sort-by').height();
    srl_heights += $('#distance-units').height();
    srl_heights += 12;
  }
  else {
    srl_heights += $('#stations-config').height();
    if ($('#time-frame').is(':visible')) {
      srl_heights += $('#time-frame').height();
      srl_heights += $('#sort-by').height();
      srl_heights += $('#distance-units').height();
      srl_heights += 23;
    }
    else {
      srl_heights += 20;
    }
  }

  $('#stations-rx-list').height($('.fullheight').height() - srl_heights);

  cth_heights = $('#tvdx-tabs').height() + $('#channel-bands').height()
              + $('#channel-sort-by').height()
              + $('#graph-time-range').height() + 11;
  $('#decodeable').height($('.fullheight').height() - cth_heights);

  $(map_or_graph).height($('#right-side').height()-$('#map-legend').height());
  $(map_or_graph).width($('#right-side').width());
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
// or set default if there is no cookie.  Also restore map lat/lng & zoom.
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
  if ($.cookie('tab-shown')) {
    $('#tvdx-tabs a[href="#' + $.cookie('tab-shown') + '"]').trigger('click');
  } else {
    $('#tvdx-tabs a[href="#tabs-stations-rx"]').trigger('click');
  }
}


// based on http://jsfiddle.net/dFNva/1/
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
    if (reverse) {
      return ((A < B) ? -1 : ((A > B) ? 1 : 0));
    }
    return ((A < B) ? 1 : ((A > B) ? -1 : 0));
  };
}


function get_sort_summary(by,val,dx,time) {
  if (by === 'distance') { return('Distance ' + dx + '<br>'); }
  if (by === 'rf-channel') { return('RF channel ' + val.rf_channel + '<br>'); }
  if (by === 'virtual-channel') { return('Virtual channel ' + val.virtual_channel + '<br>'); }
  if (by === 'time-received') { return(time + '<br>'); }
  if (by === 'azimuth') { return('Azimuth ' + val.azimuth + '&deg;<br>'); }
  return('');
}


function update_stations_received(sort_val, distance_units) {
  "use strict";
  var z_top = 10000;
  // sort data
  var field = 'miles', asc = true, primer = parseInt, dx, height, t, time;
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
    var glyph_color_class = '';
    if (new Date().getTime() < new Date(val.last_in).getTime() + 300000) {
      if (val.color === 'red') {
        glyph_color_class = 'glyph-red';
      }
      if (val.color === 'yellow') {
        glyph_color_class = 'glyph-yellow';
      }
      if (val.color === 'green') {
        glyph_color_class = 'glyph-green';
      }
    }
    if (typeof(val.rcamsl) === 'string') {
      if (distance_units === 'miles') {
        dx = val.miles + ' miles';
        height =
           parseInt(parseFloat(val.rcamsl.split(' ')[0]) * 3.2808, 10) + ' ft.';
      } else {
        dx = parseInt( val.miles * 1.609344 * 10, 10) / 10 + ' km';
        height = val.rcamsl;
      }
    } else {
      height = 'unknown';
    }
    t = new Date(val.last_in);
    if ($('#time-frame .active').attr('value') === 'ever') {
      time = t.getMonth() + 1 + '/' + t.getDate() + '/' + t.getFullYear();
    }
    else {
      time = t.getMonth() + 1 + '/' + t.getDate();
    }
    time = time + ' ' + t.toLocaleTimeString();
    var sort_summary = get_sort_summary(sort_val,val,dx,time);
    $("#stations-received-ul").append(
         '<li class="sr-list">'
       + '<span class="glyphicon glyphicon-zoom-in"></span> '
       + '<a class="callsign">' + val.callsign + '</a><br>'
       + val.city_state + '<br>'
       + '<div class="hidden-lg hidden-md">' + sort_summary + '</div>'
       + '<div class="hidden-xs hidden-sm">'
         + '<span class="glyphicon glyphicon-signal ' + glyph_color_class + '"></span>'
         + '<a href=' + root_url + '/signal_graph/' + tuner_id + '/' + tuner_number + '/' + val.callsign + '> Graphs</a><br>'
         + 'RF channel ' + val.rf_channel + '<br>'
         + 'Virtual channel ' + val.virtual_channel + '<br>'
         + 'ERP ' + val.erp + '<br>'
         + 'RCASML ' + height + '<br>'
         + 'Azimuth ' + val.azimuth + '&deg;<br>' 
         + 'Distance ' + dx + '<br>'
         + time + '<br>'
       + '</div>'
       + "<hr></li>");
  });
  // view callsign icon on top and center of map when call in list is clicked
  $.each($('.callsign'),
         function () {
           $(this).click(function () {
             $('#stations-map').gmap3({map:{options:{
               zoom: 10,
               center: $('#stations-map').gmap3({get:{id:this.innerHTML}}).getPosition()}}});
             // move marker to top in case it's below other markers
             $('#stations-map').gmap3({get: {id:this.innerHTML}}).setZIndex(z_top);
             z_top += 2;
           });
         }
  );
}


function update_map() {
  "use strict";
  var distance_units, values = [], options = [];
  var map_options = [];
  if ($('#time-frame .active').attr('value') === 'last-24-hours') {
    $('#stations-map').gmap3({clear: { name: 'marker' }});
  }
  distance_units = $('#distance-units .active').attr('value');

  // iterate over tuner_map_data and build data structure for gmap3 placement
  $.each(tuner_map_data.markers,function () {
    var height = 0, dx = 0, fill_color, fore_color;
    if (typeof(this.rcamsl) === 'string') {
      if (distance_units === 'miles') {
        dx = this.miles + ' miles';
        height =
          parseInt(parseFloat(this.rcamsl.split(' ')[0]) * 3.2808, 10) + ' ft.';
      } else {
        dx = parseInt(this.miles * 1.609344 * 10, 10) / 10 + ' km';
        height = this.rcamsl;
      }
    } else {
      height = 'unknown';
    }

    // black markers and white letters for old stations
    fill_color = "#000000";
    fore_color = "#FFFFFF";

    if (new Date().getTime() < new Date(this.last_in).getTime() + 300000) {
      fore_color = "#000000";
      if (this.color === 'red') {
        fill_color = '#FF0000';
      }
      if (this.color === 'yellow') {
        fill_color = '#FFFF00';
      }
      if (this.color === 'green') {
        fill_color = '#00FF00';
      }
    }

    values.push({
      id: this.callsign,
      latLng: [this.latitude,this.longitude],
      data: this.callsign + '<br>' +
        'RF Channel ' + this.rf_channel + '<br>' +
        'Virtual Channel ' + this.virtual_channel + '<br>' +
        this.city_state + '<br>' +
        'RCAMSL ' + height + '<br>' +
        'Azimuth ' + this.azimuth + '&deg;<br>' +
        'DX ' + dx + '<br>' +
        '<span class="glyphicon glyphicon-signal"></span>' +
        '<a href=' + root_url + '/signal_graph/' + tuner_id + '/' + tuner_number + '/' + this.callsign + '> Graphs</a><br>',
      options: { styleIcon: new StyledIcon( StyledIconTypes.BUBBLE,
                                            { color: fill_color,
                                              fore: fore_color,
                                              text: this.callsign.replace(/-.*$/,"") + ' ' + this.rf_channel }) }
    });
  });

  $('#map-progress-bar').toggle(false); //hide map progress bar
  $('#stations-map').toggle(true); // show map
  $('#map-legend').toggle(true); // show map legend
  if (   $.cookie('lat-' + tuner_id + tuner_number)
      && $.cookie('lng-' + tuner_id + tuner_number)
      && $.cookie('zoom-' + tuner_id + tuner_number)) {
    map_options = { center: [$.cookie('lat-' + tuner_id + tuner_number),
                             $.cookie('lng-' + tuner_id + tuner_number)],
                    zoom: $.cookie('zoom-' + tuner_id + tuner_number) };
  }
  $('#stations-map').gmap3({
    options: map_options,
    defaults:{ classes:{ Marker:StyledMarker } },
    marker: {
      values: values,
      events:{
        click: function(marker, event, context) {
          var map = $(this).gmap3("get"),
            infowindow = $(this).gmap3({get:{name:"infowindow"}});
          if (infowindow){
            infowindow.open(map, marker);
            infowindow.setContent(context.data);
          } else {
            $(this).gmap3({
              infowindow:{
                anchor:marker,
                options:{content: context.data}
              }
            });
          }
        }
      }
    }
  }, "autofit");
  // save lat/lng and zoom cookies
  $.cookie('lat-' + tuner_id + tuner_number,
           $('#stations-map').gmap3({get:{name:'map'}}).getCenter().lat());
  $.cookie('lng-' + tuner_id + tuner_number,
           $('#stations-map').gmap3({get:{name:'map'}}).getCenter().lng());
  $.cookie('zoom-' + tuner_id + tuner_number,
           $('#stations-map').gmap3({get:{name:'map'}}).getZoom());
}


function update_page() {
  "use strict";
  update_stations_received();
  update_map();
}


function json_and_update () {
  "use strict";
  $.getJSON(   root_url + "/tuner_map_data/"
             + tuner_id + "/" + tuner_number + "/24hour",
            function (tmd) { tuner_map_data = tmd;
                             update_page();
            });
}


// click handler for Stations tab
$('#tvdx-tabs a[href="#tabs-stations-rx"]').click(function (e) {
  "use strict";
  e.preventDefault();
  $.cookie('tab-shown','tabs-stations-rx');
  if (map_or_graph === '#channel-graphs') {
    // trying to clear 'ever' markers is waaay too slow, reload is quicker.
    map_or_graph = '#stations-map';
    document.location.reload()
    return;
  }
  $(this).tab('show');
  $('#channel-graphs').toggle(false); // hide channel graphs
  $('#graph-progress-bar').toggle(false); // in case page is in odd state
  $('#map-progress-bar').toggle(true); // start map progress bar
  map_or_graph = '#stations-map';
  if ($('#time-frame .active').attr('value') === 'last-24-hours') {
    json_and_update();
    tmd_interval = setInterval(json_and_update, 300000);
  } else {
    $.getJSON(   root_url
               + "/tuner_map_data/" +tuner_id+ "/" + tuner_number + "/ever",
              function (tmd) { tuner_map_data = tmd;
                               update_page();
              });
  }
});
// resize once shown
$('#tvdx-tabs a[href="#tabs-stations-rx"]').on('shown.bs.tab', function () {
  "use strict";
  adjust_height();
  $.cookie('tab-shown','tabs-stations-rx');
});


// click handler for Channels tab
$('#tvdx-tabs a[href="#tabs-channel"]').click(function (e) {
  "use strict";
  map_or_graph = '#channel-graphs';
  e.preventDefault();
  $(this).tab('show');
  $.cookie('tab-shown','tabs-channel"');
  $('#stations-map').toggle(false); // hide map
  $('#map-legend').toggle(false); // hide map legend
  $('#map-progress-bar').toggle(false); // in case page is in odd state
  $('#graph-progress-bar').toggle(true); // start graph progress bar
});
$('#tvdx-tabs a[href="#tabs-chcannel"]').on('show.bs.tab', function (e) {
  "use strict";
  map_or_graph = '#channel-graphs';
  // stop tuner_map_data update
  clearInterval(tmd_interval);
  // TODO: select css for channel graphs
  // TODO: present graphs.  repeat every 5 min.
});
$('#tvdx-tabs a[href="#tabs-channel"]').on('shown.bs.tab', function () {
  "use strict";
  adjust_height();
  $.cookie('tab-shown','tabs-channel');
});


// button click event handlers
$('#btn-config').click(function () {
  "use strict";
  if ($('#btn-config').text() === 'Show Configure') {
    $('#time-frame').show();
    $('#sort-by').show();
    $('#distance-units').show();
    $('#stations-rx-list').removeClass('btn-group-box-top');
    $('#btn-config').text('Hide Configure');
  }
  else {
    $('#time-frame').hide();
    $('#sort-by').hide();
    $('#distance-units').hide();
    $('#stations-rx-list').addClass('btn-group-box-top');
    $('#btn-config').text('Show Configure');
  }
  adjust_height();
});

$("#time-frame .btn").click(function () {
  "use strict";
  $.cookie('time-frame', $(this).attr('value'));
  if ($(this).attr('value') === "last-24-hours") {
    // trying to clear 'ever' markers is waaay too slow, reload is quicker.
    document.location.reload();
  } else {
    $('#stations-map').toggle(false);
    $('#map-legend').toggle(false);
    $('#map-progress-bar').toggle(true);
    $('#stations-map').gmap3({ action: 'destroy' });
    $('#black-text').text('Signal received in the past');
    clearInterval(tmd_interval);
    $.getJSON(   root_url
               + "/tuner_map_data/" + tuner_id + "/" + tuner_number + "/ever",
              function (tmd) { tuner_map_data = tmd;
                               update_page(); });
  }
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
// or on defaults, then trigger tab which starts the map or graph pages
restore_saved();

/*
var first_data_xhr =
  $.getJSON(root_url + "/tuner_map_data/" + tuner_id + "/" + tuner_number,
            function(tmd) { "use strict"; tuner_map_data = tmd; });
var gmap_xhr =
  $.getScript(static_url+'/gmap3.min.js',
              function () { "use strict"; $('#right-side').gmap3(); });
$.when(first_data_xhr, gmap_xhr).done(update_page);
*/

// top-level functions
$(window).resize(adjust_height);
