// javascript to render all_stations_ever_map
window.onerror = function(m,u,l) {
  console.error('msg:',m,'url:',u,'line:',l);
  return true
}

var map;
var infoWindow;
var bounds;
var pathBatch = {};
var iconBatch = {};
var infoWindowBatch = {};
var sidebar_list = {};
var sidebar_dx = {};

for(var i=0; i< tuner_id.length; i++) {
  var tuner_id_num = tuner_id[i] + tuner_number[i];
  pathBatch[tuner_id_num] = {};
  infoWindowBatch[tuner_id_num] = {};
}


function addPathBatch(paths,t_id,t_num,t_lat,t_lng) {
  var tuner_id_number = t_id + t_num;
  // Google maps uses -9,000,000 to 9,000,000 so start at 10,000,000
  var zBase = 10000000;
  var stroke_color = '#000000';

  var t_latlng = new google.maps.LatLng(t_lat, t_lng);

  // add paths
  for(var i=0; i<paths.length; i++) {
    var callsign = paths[i].callsign;

    paths[i].zIndex = zBase + i*10;
    var latlng = new google.maps.LatLng(paths[i].latitude, paths[i].longitude);
    bounds.extend(latlng);

    // new polyline
    var so = 0.25; //opacity
    var sw = 1; //weight
    pathBatch[tuner_id_number][callsign] =
      new google.maps.Polyline({map: map,
                                path: [latlng, t_latlng],
                                geodesic: 1, // draw great circle route
                                strokeWeight: sw,
                                strokeOpacity: so,
                                strokeColor: stroke_color,
                                zIndex: paths[i].zIndex});
    pathBatch[tuner_id_number][callsign].setMap(map);

    // add icon if call isn't on map already
    if (typeof(iconBatch[callsign]) == 'undefined') {
      var iconPath = '/static/images/' + callsign + '.png';
      iconBatch[callsign] =
        new google.maps.Marker({map: map,
                                position: latlng,
                                icon: new google.maps.MarkerImage(iconPath),
                                zIndex: paths[i].zIndex+1000,
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

    // add or change (if DX is greater) call to sidebar_list
    if (   (typeof(sidebar_list[callsign]) == 'undefined')
        || (sidebar_dx[callsign] < paths[i].distance)) {
      sidebar_list[callsign] = '<div class="label">' +
                           paths[i].callsign +
                           '</div><a>' +
                           paths[i].info +
                           paths[i].azimuth_dx +
                           '</a>';
      sidebar_dx[callsign] = paths[i].distance
    }
  }
}


function updatePaths() {
  for(var i=0; i<tuner_id.length; i++) {
    new Ajax.Request(
      "/tvdx/all_stations_data/" + tuner_id[i] + '/' + tuner_number[i],
      {
        method:'get',
        onSuccess: function(responseJSON) { 
          var json = responseJSON.responseText.evalJSON();

          var t_id = json.tuner_id;
          var t_num = json.tuner_number;
          var t_lat = json.tuner_latitude;
          var t_lng = json.tuner_longitude;

          addPathBatch(json.black_markers,t_id,t_num,t_lat,t_lng)
          update_sidebar_list();

          map.fitBounds(bounds);
        }
      }
    );
  }
}


function update_sidebar_list() {
  // clear sidebar-list on page
  var sb_list = $('sidebar-list');
  while(sb_list.hasChildNodes()) {
    sb_list.removeChild(sb_list.lastChild);
  }

  // sort sidebar_list on sidebar_dx
  var callsigns = [];
  for (callsign in sidebar_list) { callsigns.push(callsign) }
  callsigns.sort( function(a,b) { return sidebar_dx[a] < sidebar_dx[b]} );

  // add info to sidebar-list on page
  for (var i=0; i < callsigns.length; i++) {
    var listItem = document.createElement('li');
    listItem.innerHTML = sidebar_list[callsigns[i]];
    sb_list.appendChild(listItem);
  }
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
