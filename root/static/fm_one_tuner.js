jQuery.noConflict();
var map;
var station_m;   //station marker layer group
var station_l;   //lines (between receiver and transmitter) layer group
var station_mt;  //(markers on top activated by zoom in sidebar) layer group
var onepixel;
var json;
var markers = {}; // dictionary of markers to populate station_mt from
var sidebar = {}; // key is sort-by
var pe;           // PeriodicalExecutor instance

// CORS preflight options check rejection fix
Ajax.Responders.register({
    onCreate:function(r){
        r.options.requestHeaders={
        'X-Prototype-Version':null,
        'X-Requested-With':null
        };
    }
});

(function( $ ) { // use jquery $, not prototype.js $
// send errors to console for debugging
window.onerror = function(m,u,l) {
  console.error('msg:',m,'url:',u,'line:',l);
  return true
}

$.cookie.defaults.path = '/';
$.cookie.defaults.expires = 1000;


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
  restore_radio_button('frequency-sort-by', "frequency");
  restore_radio_button('graph-time-range', "hourly");
  if ($.cookie('tab-shown')) {
    $('#tvdx-tabs a[href="#' + $.cookie('tab-shown') + '"]').trigger('click');
  } else {
    $('#tvdx-tabs a[href="#tabs-stations-rx"]').trigger('click');
  }
}


function init() {
  "use strict";
  restore_saved();
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
  });

  $("#time-frame .btn").click(function (e) {
    "use strict";
    $.cookie('time-frame', $(this).attr('value'), { expires : 365, path: "/;SameSite=Strict", secure: true});
    if (typeof(pe) !== 'undefined') {
      pe.stop();
      pe = undefined;
    }
    if (e.target.getAttribute('value') === "last-24-hours") {
      ucm_24();
      pe = new PeriodicalExecuter(ucm_24,300);
    } else {
      ucm_ever();
      pe = new PeriodicalExecuter(ucm_ever,300);
    }
  });

  $("#sort-by .btn").click(function () {
    "use strict";
    $.cookie('sort-by', $(this).attr('value'), { expires : 365, path: "/;SameSite=Strict", secure: true});
    fill_sidebar($(this).attr('value'));
    set_units($('#distance-units .active').attr('value'));
  });
  $("#distance-units .btn").click(function(e) {
    set_units(e.target.getAttribute('value'));
    $.cookie('distance-units', e.target.getAttribute('value'), { expires : 365, path: "/;SameSite=Strict", secure: true});
  });
  $("#stations-map").outerHeight(
      $("#right-side").outerHeight()
    - $("#map-legend").outerHeight()
    - 2);

  // requires esri-leaflet.js and ESRI could change the terms of service anytime
  var streets = L.esri.basemapLayer('Streets',{ maxZoom:15, minZoom:3 });
  var topo = L.esri.basemapLayer('Topographic',{ maxZoom:15, minZoom:3 });
  var photo = L.esri.basemapLayer('Imagery',{ maxZoom:15, minZoom:3 });
  map = L.map('stations-map', { layers: [streets] });
  L.control.layers({ 'Streets' : streets,
                     'Topographic' : topo,
                     'Imagery' : photo }).addTo(map);
  station_m = L.layerGroup();
  station_l = L.layerGroup();
  station_mt = L.layerGroup();
  onepixel = L.icon({
    iconUrl: static_url + '/images/1x1.png',
    iconSize: [1, 1]
  });
  // for stations moved to top by zoom buttons in sidebar (station_mt markers)
  map.createPane('topTooltip');
  map.createPane('topPopup');
  map.getPane('topTooltip').style.zIndex = 800;
  map.getPane('topPopup').style.zIndex = 900;

  if ($.cookie('time-frame') !== "ever") {
    ucm_24();
    pe = new PeriodicalExecuter(ucm_24,300);
  } else {
    ucm_ever();
    pe = new PeriodicalExecuter(ucm_ever,300);
  }
  window.addEventListener("resize", function () {
    $("#stations-map").outerHeight(
        $("#right-side").outerHeight()
      - $("#map-legend").outerHeight()
      - 2);
    map.invalidateSize();
  });
}


function update_call_markers(url) {
  "use strict";
  new Ajax.Request(
    url,
    {
      method:'get',
      onSuccess: function(responseJSON) {
        map.removeLayer(station_m);
        map.removeLayer(station_l);
        map.removeLayer(station_mt);
        station_m.clearLayers();
        station_l.clearLayers();
        station_mt.clearLayers();
        markers = {};
        json = responseJSON.responseText.evalJSON();
        var tuner_ll = new L.LatLng(json.tuner_latitude,json.tuner_longitude);

        var station_ll = [];
        for(var i=0; i<json.markers.length; i++) {
          var m = json.markers[i];
          var mhz = m.frequency.toString();
          mhz = mhz.replace('000000','');
          var hkhz = mhz.slice(-1);
          mhz = mhz.substr(0,mhz.length-1);
          mhz = mhz + '.' + hkhz;
          var call_mhz = m.callsign.replace(/-.*$/,"") + mhz;
          m.color = 'black';
          station_ll[i] = new L.LatLng(m.latitude,m.longitude);
          var popup_text = m.callsign + '<br>' +
                      'Frequency ' + mhz + '<br>' +
                      m.city_state + '<br>' +
                      'HAAT-V ' + m.haat_v + ' m<br>' + 
                      'HAAT-H ' + m.haat_h + ' m<br>' + 
                      'Azimuth ' + m.azimuth + '&deg<br>' +
                      'Distance ' + m.km + ' km<br>';
          markers[call_mhz] = L.marker(station_ll[i], {icon: onepixel })
                           .bindTooltip(call_mhz,
                                        { interactive: true,
                                          permanent: true,
                                          direction: 'top',
                                          className: 'marker_' + m.color,
                                          offset: [0, 2] })
                              .bindPopup(popup_text);
          var marker = L.marker(station_ll[i], {icon: onepixel })
                        .bindTooltip(call_mhz,
                                     { interactive: true,
                                       permanent: true,
                                       direction: 'top',
                                       className: 'marker_' + m.color,
                                       offset: [0, 2] })
                        .bindPopup(popup_text);
          station_m.addLayer(marker);
          m.markers_key = call_mhz;
          station_l.addLayer(
              L.geodesic([tuner_ll, station_ll[i]],
                         { weight: 3,
                           opacity: (m.color === 'black') ? 0.25 : 1,
                           zIndexOffset: (m.color === 'black') ? -500 : 0,
                           color: m.color,
                           steps: 4 }));
        }
        set_units($('#distance-units .active').attr('value'));
        station_ll.push(tuner_ll);
        map.fitBounds(station_ll);
        map.addLayer(station_m);
        map.addLayer(station_l);
        update_sidebar(json.markers);
      }
    }
  );
}


function set_units(units) {
  "use strict";
  station_m.eachLayer(function(layer) {
    var po = layer.getPopup().getContent();
    layer.getPopup().setContent(change_units(po,units));
  });
  station_mt.eachLayer(function(layer) {
    var po = layer.getPopup().getContent();
    layer.getPopup().setContent(change_units(po,units));
  });
  $("#stations-received-ul .sr-list").each(function (index,element) {
    element.innerHTML = change_units(element.innerHTML,units);
  });
  function change_units(str,units) {
    "use strict";
    if (units === 'km') {
      var arr, dx_miles, miles_str, miles, km, dx_km, rc_ft, ft_str, ft, m;
      arr = /Distance (.*?) miles/.exec(str);
      if (arr !== null) {
        [dx_miles,miles_str] = arr;
        miles = parseFloat(miles_str);
        km = parseInt( miles * 1.609344 * 10, 10) /10 + ' km';
        dx_km = 'Distance ' + km;
        str = str.replace(new RegExp(dx_miles,'g'),dx_km);
      }
      arr = /RCAMSL (.*) ft\./.exec(str);
      if (arr !== null) {
        [rc_ft,ft_str] = arr;
        ft = parseFloat(ft_str);
        m = 'RCAMSL ' + parseInt(ft * .3048 *10, 10) /10 + ' m.'
        str = str.replace(rc_ft,m);
      }
    }
    else {
      var arr, dx_km, km_str, km, miles, dx_miles, rc_m, m_str, meters, feet, rc_ft;
      arr = /Distance (.*?) km/.exec(str);
      if (arr !== null) {
        [dx_km,km_str] = arr;
        km = parseFloat(km_str);
        miles = parseInt( km * 0.621371 * 10, 10) /10 + ' miles';
        dx_miles = 'Distance ' + miles;
        str = str.replace(new RegExp(dx_km,'g'),dx_miles);
      }
      arr = /RCAMSL (.*) m\./.exec(str);
      if (arr !== null) {
        [rc_m,m_str] = arr;
        meters = parseInt(m_str);
        feet = parseInt(parseFloat(meters * 3.2808, 10));
        rc_ft = 'RCAMSL ' + feet + ' ft.';
        str = str.replace(rc_m,rc_ft);
      }
    }
    return(str);
  }
}


function update_sidebar(markers) {
  "use strict";
  update_text('distance',markers.sort(sort_by('miles', false, parseFloat)));
  update_text('frequency',markers.sort(sort_by('frequency', true, parseInt)));
  update_text('time-received',markers.sort(sort_by('last_in', false, Date)));
  update_text('azimuth',markers.sort(sort_by('azimuth', true, parseInt)));
  update_text('callsign',markers.sort(sort_by('callsign', true, undefined)));

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
  function update_text(field,arr) {
    "use strict";
    var dx, height_h, height_v, t, time, sort_summary;
    sidebar[field] = [];
    arr.forEach(function (val) {
      var glyph_color_class = 'glyph-black';
      dx = val.km + ' km';
      if (typeof(val.haat_h) === 'number' && val.haat_h > 0) {
        height = val.haat_h.toString() + ' m.';
      } else {
        height_h = 'unknown';
      }
      if (typeof(val.haat_v) === 'number' && val.haat_v > 0) {
        height = val.haat_v.toString() + ' m.';
      } else {
        height_v = 'unknown';
      }

      t = new Date(val.last_in);
      if ($('#time-frame .active').attr('value') === 'ever') {
        time = t.getMonth() + 1 + '/' + t.getDate() + '/' + t.getFullYear();
      }
      else {
        time = t.getMonth() + 1 + '/' + t.getDate();
      }
      time = time + ' ' + t.toLocaleTimeString();
      sort_summary = get_sort_summary(field,val,dx,time);
      sidebar[field].push(
         '<li class="sr-list">'
       + '<span class="glyphicon glyphicon-zoom-in"></span> '
       + '<a class="callsign" value="' + val.markers_key + '">' + val.callsign + '</a><br>'
       + val.city_state + '<br>'
       + '<div class="hidden-lg hidden-md">' + sort_summary + '</div>'
       + '<div class="hidden-xs hidden-sm">'
       + 'Frequency ' + val.frequency + '<br>'
       + 'ERP H' + val.erp_h + '<br>'
       + 'ERP V' + val.erp_v + '<br>'
       + 'HAAT H ' + height_h + '<br>'
       + 'HAAT V ' + height_v + '<br>'
       + 'Azimuth ' + val.azimuth + '&deg;<br>'
       + 'Distance ' + dx + '<br>'
       + time + '<br>'
       + '</div>'
       + "<hr></li>");
    });
  }
  function get_sort_summary(by,val,dx,time) {
    "use strict";
    if (by === 'distance') { return('Distance ' + dx + '<br>'); }
    if (by === 'frequency') { return('Frequency ' + val.frequency + '<br>'); }
    if (by === 'time-received') { return(time + '<br>'); }
    if (by === 'azimuth') { return('Azimuth ' + val.azimuth + '&deg;<br>'); }
    return('');
  }
  fill_sidebar($('#sort-by .active').attr('value'));
}


function fill_sidebar(sortby) {
  "use strict";
  $("#stations-received-ul").empty().append(sidebar[sortby])
  .on("click",".callsign",function (e) {
    // copy clicked station_m marker to station_mt, recenter and redraw
    var ll = markers[e.target.getAttribute('value')].getLatLng();
    map.removeLayer(station_mt);
    station_mt.clearLayers();
    map.setView(ll,10);
    station_mt.addLayer(markers[e.target.getAttribute('value')]);
    map.addLayer(station_mt);
  });
}
function ucm_24 () {
  update_call_markers(root_url + "/fm_map_data/" + tuner_key + '/24hrs');
}
function ucm_ever () {
  update_call_markers(root_url + "/fm_map_data/" + tuner_key + '/ever');
}


  
init();
})( jQuery );
