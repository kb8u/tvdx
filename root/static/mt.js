jQuery.noConflict();
var by_longitude  = [];
var map;
var station_mt = {};  //station markers with tooltip on top
var station_mb = {};  //station markers with tooltip on bottom
var tuner_mt = {};    //tuner markers with tooltip on top
var tuner_mb = {};    //tuner markers with tooltip on bottom
var lines;   // layerGroup of lines between receiver and transmitter
var stations; // layerGroup of station markers show on both ends of a path
var on_top;  // used by tuners list mouseover and lines on mouseover
var onepixel;
var json;
var station_props = {};
var tuner_longlat = {};
var curDateTime;
var extent = {};

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

// for searching the paths layer group
L.LayerGroup.include({
  gettvdxLayer: function (callsign,tuner) {
    for (var i in this._layers) {
      if (this._layers[i].callsign === callsign && this._layers[i].tuner === tuner) {
        return this._layers[i];
      }
    }
  }
});

// current time for top bar
function update_time_str() {
  curDateTime = new Date();
  var curHour = curDateTime.getHours();
  var curMin = curDateTime.getMinutes();
  var curAMPM = " AM";
  var curTime = "";
  if (curHour >= 12){
    curHour -= 12;
    curAMPM = " PM";
  }
  if (curHour == 0) curHour = 12;
  curTime = curHour + ":" + ((curMin < 10) ? "0" : "") + curMin + curAMPM;

  var date = curDateTime.getDate();
  var month = curDateTime.getMonth();
  var year = curDateTime.getYear();
  month = month + 1;
  if(year<1000) year+=1900;
  return('TV stations receieved as of ' + curTime + " " + month + "/" + date + "/" + year);
}


function update_tuners_list() {
  $('#sidebar-list').empty();
  by_longitude = json.json.tuners.features.map(function(t){
     return {'description' : t.properties.description.replace(/tuner\d$/,''),
             'longitude'   : t.geometry.coordinates[0],
             'url_path'    : t.properties.url_path,
             'url'         : root_url+'/one_tuner_map/'+t.properties.url_path };
  });
  by_longitude.sort(function(a,b){return b.longitude-a.longitude}).forEach(
    function(t) {
      var a = '<li><a href="'+t.url+'" url_path="'+t.url_path+'">'
            + t.description+'</a></li>';
      $('#sidebar-list').append(a);
    });
  $('li a')
  .on('mouseover focus',function (e) {
               if (e.target.hasAttribute('url_path')) {
                 on_top.addLayer(tuner_mt[e.target.getAttribute('url_path')]);
               }
             })
  .on('mouseout focusout',function () { on_top.clearLayers() })
  .click(function (e) {
           if (e.altKey) {
              map.setView(
                [tuner_longlat[e.target.getAttribute('url_path')][1],
                 tuner_longlat[e.target.getAttribute('url_path')][0]], 8);
            }
         });
}


function update() {
  "use strict";

  new Ajax.Request(
    root_url + "/all_tuner_data",
    {
      method:'get',
      onSuccess: function(responseJSON) {
        $("#lastUpdateTime").html(update_time_str());
        json = responseJSON.responseText.evalJSON();
        update_tuners_list();
        lines.clearLayers();
        stations.clearLayers();
        on_top.clearLayers();
        extent = {n:0, s:90, e:-179.9, w:0};
        var i;
        for(i=0; i< json.json.tuners.features.length; i++) {
          var t=json.json.tuners.features[i];
          tuner_longlat[t.properties.url_path] = t.geometry.coordinates;
          if (!(t.properties.url_path in tuner_mt)) {
            // geojson is long-lat
            var ll = new L.LatLng(t.geometry.coordinates[1],t.geometry.coordinates[0]);
            var tmarker = L.marker(ll, {icon: onepixel}).bindTooltip(
              // tunerX is the default but useless description of a tuner
              t.properties.description.replace(/tuner\d$/,''),
              { interactive: true, permanent: true, direction: 'top' }
            );
            tuner_mt[t.properties.url_path] = tmarker;
            tmarker = L.marker(ll, {icon: onepixel}).bindTooltip(
              t.properties.description.replace(/tuner\d$/,''),
              { interactive: true, permanent: true, direction: 'bottom' }
            );
            tuner_mb[t.properties.url_path] = tmarker;
          }
        }
        for(i=0; i< json.json.stations.features.length; i++) {
          var s=json.json.stations.features[i];
          station_props[s.properties.callsign] = s.properties;
          if (!(s.properties.callsign in station_mt)) {
            var ll = new L.LatLng(s.geometry.coordinates[1],s.geometry.coordinates[0]);
            var smarker = L.marker(ll, {icon: onepixel}).bindTooltip(
              s.properties.callsign + ' ' + s.properties.rf_channel,
              { interactive: true, permanent: true, direction: 'top' }
            );
            station_mt[s.properties.callsign] = smarker;
            smarker = L.marker(ll, {icon: onepixel}).bindTooltip(
              s.properties.callsign + ' ' + s.properties.rf_channel,
              { interactive: true, permanent: true, direction: 'bottom' }
            );
            station_mb[s.properties.callsign] = smarker;
          }
        }
        for(i=0; i< json.json.paths.features.length; i++) {
          var p = json.json.paths.features[i].properties;
          var c = json.json.paths.features[i].geometry.coordinates;
          var color;
          var z; // zindexoffset.  Put black lines on bottom
          var o; // opacity.  Make black lines less opaque.
          if (curDateTime.getTime() > new Date(p.rx_date).getTime() + 300000) {
            color = 'black';
            o = 0.25;
            z = 0;
          } else {
            color = p.color;
            o = 1;
            z = -500;
          }
          // on mouseover, create duplicate (but thicker) line on top.
          // on mouseout on new line, clear the top layer.
          var line = 
            L.geodesic( [ [c[0][1],c[0][0]], [c[1][1],c[1][0]] ],
                        { weight: 3,
                          opacity: o,
                          color: color,
                          zIndexOffset: z,
                          steps: 4 })
            .on({ mouseover: function(e) {
                    on_top.clearLayers();
                    stations.clearLayers();
                    var m = lines.getLayer(e.target._leaflet_id);
                    var ll = m.getLatLngs();
                    var options = e.target.options;
                    options['weight'] = 6;
                    options['pane'] = 'topLine';
                    options['bubblingMouseEvents'] = true;
                    var nm = L.geodesic(ll,options)
                      .on({mouseout:
                             function(e){
                               on_top.clearLayers();
                               stations.clearLayers();
                             },
                           click:
                             function(e) {
                               lines.gettvdxLayer(e.target.callsign,e.target.tuner).openPopup();
                             }
                          });
                    nm.callsign = m.callsign;
                    nm.tuner = m.tuner; 
                    on_top.addLayer(nm);
                    // Choose layers so tooltips can't be on top of each other.
                    if (tuner_mt[e.target.tuner].getLatLng().lat > station_mt[e.target.callsign].getLatLng().lat) {
                      stations.addLayer(tuner_mt[e.target.tuner]);
                      stations.addLayer(station_mb[e.target.callsign]);
                    } else {
                      stations.addLayer(tuner_mb[e.target.tuner]);
                      stations.addLayer(station_mt[e.target.callsign]);
                    }
                  }
                }
          );

          var popup_text = (color === 'black')
                         ? 'Last report: '+new Date(p.rx_date).toLocaleString()+'<br>'
                         : '';
          var dx = ($.cookie('distance-units') !== 'miles')
                 ? Math.round(line.statistics.totalDistance/100)/10+' km'
                 : Math.round(line.statistics.totalDistance*0.00621371)/10+' miles';
          var height = ($.cookie('distance-units') !== 'miles')
                 ? station_props[p.callsign]['rcamsl'] + ' meters'
                 : Math.round(station_props[p.callsign]['rcamsl']*3.28084)+ ' feet';
          popup_text = popup_text +
           p.description + '<br>' +
           'Distance: ' + dx + '<br>'+
           'RF Channel: '+ p.rf_channel + '<br>' +
           'Virtual Channel: ' + p.virtual_channel + '<br>' +
           'RCAMSL: ' + height + '<br>' +
           'ERP: ' + station_props[p.callsign]['erp_kw'] + '<br>' +
           '<a href="'+root_url+'/one_tuner_map/'+p.tuner_id+'/'+p.tuner_number+'">Single Location Map</a><br>' +
           '<a href="'+root_url+'/signal_graph/'+p.tuner_id+'/'+p.tuner_number+'/'+p.callsign+'">Signal Graph</a><br>';
          line.bindPopup(popup_text, { pane: 'topPopup' });

          line.callsign = p.callsign;
          line.tuner = p.tuner_id+'/'+p.tuner_number;
          lines.addLayer(line);

          extent.n = (c[0][1] > extent.n) ? c[0][1] : extent.n;
          extent.n = (c[1][1] > extent.n) ? c[1][1] : extent.n;
          extent.s = (c[0][1] < extent.s) ? c[0][1] : extent.s;
          extent.s = (c[1][1] < extent.s) ? c[1][1] : extent.s;
          extent.e = (c[0][0] > extent.e) ? c[0][0] : extent.e;
          extent.e = (c[1][0] > extent.e) ? c[1][0] : extent.e;
          extent.w = (c[0][0] < extent.w) ? c[0][0] : extent.w;
          extent.w = (c[1][0] < extent.w) ? c[1][0] : extent.w;
        }

        if (typeof($.cookie('bounds')) !== 'undefined') {
          var b = $.cookie('bounds').split(',').map(function(v){return parseFloat(v)});
          map.fitBounds([[b[1],b[0]],[b[3],b[2]]]);
        } else {
        map.fitBounds([[extent.s,extent.w], [extent.n,extent.e]]);
        }
      }
    }
  );
}


function init() {
  "use strict";

  $("#map-and-sidebar").outerHeight( $(window).height() - $("#time-and-legend").outerHeight());

  window.addEventListener("resize", function () {
    $("#map-and-sidebar").outerHeight( $(window).height() - $("#time-and-legend").outerHeight());
    map.invalidateSize();
  });

  // requires esri-leaflet.js and ESRI could change the terms of service anytime
  var streets = L.esri.basemapLayer('Streets',{ attribution:attribution, maxZoom:15, minZoom:3 });
  var topo = L.esri.basemapLayer('Topographic',{ attribution:attribution, maxZoom:15, minZoom:3 });
  var photo = L.esri.basemapLayer('Imagery',{ attribution:attribution, maxZoom:15, minZoom:3 });
  map = L.map('stations-map', { layers: [streets] });
  map.on('zoomend moveend', function(e) {
    $.cookie('bounds', map.getBounds().toBBoxString()); 
  });
  lines = L.layerGroup();
  stations = L.layerGroup();
  on_top = L.layerGroup();
  L.control.layers({ 'Streets' : streets,
                     'Topographic' : topo,
                     'Imagery' : photo }).addTo(map);

  onepixel = L.icon({
    iconUrl: './1x1.png',
    iconSize: [1, 1],
  });
  var attribution = 'TSID data thanks to <a href="www.rabbitears.info">rabbitears.info</a> | ';
  map.attributionControl.addAttribution(attribution);
  // for stations moved to top by zoom buttons in sidebar (on_top markers)
  map.createPane('topLine');
  map.createPane('topPopup');
  map.getPane('topLine').style.zIndex = 800;
  map.getPane('topPopup').style.zIndex = 900;

  map.addLayer(lines);
  map.addLayer(stations);
  map.addLayer(on_top);
  update();
}

init();
new PeriodicalExecuter(update,300);
})( jQuery );

