/*
   functions used in one_tuner_map.  Written March 9, 2013 by
   Russell Dwarshuis
*/

// send errors to console for debugging
window.onerror = function(m,u,l) {
  console.error('msg:',m,'url:',u,'line:',l);
  return true
}

var map;
var infoWindow;
var bounds;
var markersOnMap = { 'black' : {},
                     'red'   : {},
                     'yellow': {},
                     'green' : {} };
// Stack markers green on top of yellow on top of red on top of black.
// Google maps uses zIndex -9000000 to 9000000 so start black at 10,000,000
// Globals are incremented to avoid zIndex conflicts
var zBase = {}
zBase['black']  = 10000000;
zBase['red']    = 11000000;
zBase['yellow'] = 12000000;
zBase['green']  = 13000000;


function addMarkerBatch(markers,color) {
  // fill color of icon
  var fill_color;
  if (color == 'black')  {
    labelStyle = 'blackLabels';  // white letters against black background
    fill_color = '#000000';
  }
  if (color == 'red') {
    labelStyle = 'colorLabels'; // black letters against color background
    fill_color = '#FF0000';
  }
  if (color == 'yellow') {
    labelStyle = 'colorLabels'
    fill_color = '#FFFF00';
  }
  if (color == 'green') {
    labelStyle = 'colorLabels';
    fill_color = '#00FF00';
  }

  // delete markers that are no longer coming in in this strength (color)
  for (var callOnMap in markersOnMap[color]) {
    var found = 0;
    for(var i=0; i<markers.length; i++) {
      if (markers[i].callsign == callOnMap) {
        found = 1;
        break;
      }
    }
    if (found == 0) {
      // change found marker to null map to clear them off of visible map
      markersOnMap[color][callOnMap].setMap(null);
      delete markersOnMap[color][callOnMap]
    }
  }

  // create new sidebar list and add new markers to map
  for(var i=0; i<markers.length; i++) {
    var callsign = markers[i].callsign;
    var rf_channel = markers[i].info.match(/\d+/);

    // put list of stations on sidebar on right
    var listItem = document.createElement('li');
    listItem.innerHTML = '<div class="label">' + 
                         markers[i].callsign +
                         '</div><a>' +
                         markers[i].info +
                         markers[i].azimuth_dx +
                         markers[i].last_in +
                         markers[i].graphs +
                         '</a>';
    $('sidebar-list').appendChild(listItem);

    // don't add markers that are already on the map
    if (callsign in markersOnMap[color]) { continue }

    var call_loc = new google.maps.LatLng(markers[i].latitude,
                                          markers[i].longitude);
    // keep track of what markers are on map per color
    markersOnMap[color][markers[i].callsign] =
      new MarkerWithLabel({
        position : call_loc,
        draggable: false,
        raiseOnDrag: true,
        map: map,
        icon: { path: google.maps.SymbolPath.CIRCLE,
                fillColor: fill_color,
                fillOpacity: 1,
                strokeColor: "black",
                scale: 16,
                strokeWeight: 1 },
        labelContent: callsign + '<br> ' + rf_channel,
        labelAnchor: new google.maps.Point(15,6),
        labelClass: labelStyle, // the CSS class for the label
        info: callsign +
              markers[i].info +
              markers[i].azimuth_dx +
              markers[i].last_in +
              markers[i].graphs,
        zIndex: zBase[color]
      });
    zBase[color] = zBase[color] + 2; // markersOnMap uses +1 for text 

    // when clicked, marker has a pop up window with station info
    google.maps.event.addListener(
      markersOnMap[color][markers[i].callsign],
      'click',
      function() {
        infoWindow.setContent(this.info);
        infoWindow.open(map,this);
      });

    // make map bigger
    bounds.extend(call_loc);
  }

  map.fitBounds(bounds);
}


function updateCallMarkers() {
  new Ajax.Request(
    "/tuner_map_data/" + tuner_id + '/' + tuner_number,
    {
      method:'get',
      onSuccess: function(responseJSON) { 
        // clear sidebar-list
        var sb_list = $('sidebar-list');
        while(sb_list.hasChildNodes()) {
          sb_list.removeChild(sb_list.lastChild);
        }

        var json = responseJSON.responseText.evalJSON();

        addMarkerBatch(json.black_markers,'black')
        addMarkerBatch(json.red_markers,'red')
        addMarkerBatch(json.yellow_markers,'yellow')
        addMarkerBatch(json.green_markers,'green')

// BUG: bounds never contracts when distant stations disappear
// should build bounds each time from markersOnMap somehow
        map.fitBounds(bounds);
      }
    }
  );

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
  updateCallMarkers();
}


window.onresize = handleResize;
window.onload = init;

new PeriodicalExecuter(updateCallMarkers,300);
