window.onerror = function(m,u,l) {
  console.error('msg:',m,'url:',u,'line:',l);
  return true
}

var map;
var infoWindow;
var bounds;
var pathBatch = {};
var iconBatch = {};
var infoWindowBatch = {}

for(var i=0; i< tuner_id.length; i++) {
  var tuner_id_num = tuner_id[i] + tuner_number[i];
  pathBatch[tuner_id_num] = {};
  infoWindowBatch[tuner_id_num] = {};
  var colors = ['black','red','yellow','green'];
  for(var j in colors) {
    pathBatch[tuner_id_num][colors[j]] = {};
    infoWindowBatch[tuner_id_num][colors[j]] = {};
  }
}


function addPathBatch(paths,color,t_id,t_num,t_lat,t_lng) {
  var tuner_id_number = t_id + t_num;
  // sets z-index and color for path.
  // Google maps uses -9,000,000 to 9,000,000 so start black at 10,000,000
  var zBase = 10000000;
  var html_color;
  switch (color) {
    case 'red':    html_color = '#FF0000'; zBase = 11000000; break;
    case 'yellow': html_color = '#FFFF00'; zBase = 12000000; break;
    case 'green':  html_color = '#00FF00'; zBase = 13000000; break;
    default:       html_color = '#000000'; break;
  }

  var t_latlng = new google.maps.LatLng(t_lat, t_lng);

  // delete paths that are no longer active
  for(var existing in pathBatch[tuner_id_number][color]) {
    var found = 0;
    for(var i=0; i<paths.length; i++) {
      var current = paths[i].callsign;
      if (current == existing) {
        found = 1;
        break;
      }
    }
    if (found == 0) {
      pathBatch[tuner_id_number][color][existing].setMap(null);
      delete pathBatch[tuner_id_number][color][existing];
      // remove icon if callsign is no longer in pathBatch
      remove_icon(existing);
    }
  }

  // add new paths
  for(var i=0; i<paths.length; i++) {
    var callsign = paths[i].callsign;
    // already on map ?
    if (pathBatch[tuner_id_number][color][callsign] !== undefined) {
      continue;
    }

    paths[i].zIndex = zBase + i*10;
    var latlng = new google.maps.LatLng(paths[i].latitude, paths[i].longitude);
    bounds.extend(latlng);

    // new polyline
    var so = 1; //opacity
    var sw = 3; //weight
    if (color == 'black') {
      so = 0.25;
      sw = 1;
    }
    pathBatch[tuner_id_number][color][callsign] =
      new google.maps.Polyline({map: map,
                                path: [latlng, t_latlng],
                                geodesic: 1, // draw great circle route
                                strokeWeight: sw,
                                strokeOpacity: so,
                                strokeColor: html_color,
                                zIndex: paths[i].zIndex});
    pathBatch[tuner_id_number][color][callsign].setMap(map);

    // loop through pathBatch and see if callsign already exists
    if (! inPathBatch(callsign)) {
      var iconPath = static_url + '/images/' + callsign + '.png';
      iconBatch[callsign] =
        new google.maps.Marker({map: map,
                                position: latlng,
                                icon: new google.maps.MarkerImage(iconPath),
                                zIndex: paths[i].zIndex,
                                info: callsign + " " + paths[i].info});
      iconBatch[callsign].setMap(map);

      google.maps.event.addListener(
        iconBatch[callsign],
        'click',
        function() {
          infoWindow.setContent(this.info);
          infoWindow.open(map,this);
        });
    }
  }
}


function inPathBatch(callsign) {
  for(var i=0; i< tuner_id.length; i++) {
    var tuner_id_num = tuner_id[i] + tuner_number[i];
    var colors = ['black','red','yellow','green'];
      for(var j in colors) {
        if (typeof(pathBatch[tuner_id_num][colors[j]].callsign)!='undefined') {
          return 1;
        }
      }
  }
  return 0;
}


function remove_icon(callsign) {
  // loop through pathBatch and do nothing if callsign still exists
  if (inPathBatch(callsign)) { return }
  iconBatch[callsign].setMap(null);
  // remove callsign from object
  delete iconBatch[callsign];
}


function updatePaths() {
  for(var i=0; i<tuner_id.length; i++) {
    new Ajax.Request(
      root_url + "/tuner_map_data/" + tuner_id[i] + '/' + tuner_number[i],
      {
        method:'get',
        onSuccess: function(responseJSON) { 
          var json = responseJSON.responseText.evalJSON();

          var t_id = json.tuner_id;
          var t_num = json.tuner_number;
          var t_lat = json.tuner_latitude;
          var t_lng = json.tuner_longitude;

          // convert to old style data structure
          var black_markers,red_markers,yellow_markers,green_markers;
          for (var i=0;i<json.markers.length;i++) {
            var m = json.markers[i]
            var pbm = {};
            pbm.info = "<br>RF Channel " + m.rf_channel + "<br>"
                     + "Virtual channel " + m.virtual_channel + "<br>"
                     + m.city_state + "<br>ERP " + m.erp + "<br>"
                     + "RCAMSL " + m.rcamsl + "<br>";
            pbm.graphs = '<a href="' + m.graphs_url
                       + '">Signal strength graphs</a><br>';
            pbm.last_in = "last in " + m.last_in + "<br>";
            pbm.latitude = m.latitude;
            pbm.longitude = m.longitude;
            pbm.callsign = m.callsign;
            pbm.azimuth_dx = "Azimuth: " + m.azimuth + " &deg<br>DX: "
                           + m.miles + " miles<br>";
            // check if m.last_in is > 5 minutes old
            if (new Date().getTime() < new Date(m.last_in).getTime() + 300000){
              black_markers.append(pbm);
              continue;
            }
            switch(m.color) {
              case 'red':    red_markers.append(pbm);    break;
              case 'yellow': yellow_markers.append(pbm); break;
              case 'green':  green_markers.append(pbm);  break;
              default:       black_markers.append(pbm);
            }
          }
          addPathBatch(black_markers,'black',t_id,t_num,t_lat,t_lng)
          addPathBatch(red_markers,'red',t_id,t_num,t_lat,t_lng)
          addPathBatch(yellow_markers,'yellow',t_id,t_num,t_lat,t_lng)
          addPathBatch(green_markers,'green',t_id,t_num,t_lat,t_lng)

// BUG: bounds never contracts when distant stations disappear
// should build bounds each time from iconBatch somehow
          map.fitBounds(bounds);
        }
      }
    );
  }

  myCurrentTime();
}


function init() {
  handleResize();
  bounds = new google.maps.LatLngBounds();
  var initCenter = new google.maps.LatLng(42,-84);
  var mapOptions = { mapTypeId: google.maps.MapTypeId.ROADMAP,
                     zoom: 8,
                     center: initCenter }
  map = new google.maps.Map($("map"), mapOptions);
  infoWindow = new google.maps.InfoWindow();
  updatePaths();
}


window.onresize = handleResize;
window.onload = init;

new PeriodicalExecuter(updatePaths,300);
