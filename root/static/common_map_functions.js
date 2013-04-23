// display current time in top bar
function myCurrentTime() {
  var curDateTime = new Date()
  var curHour = curDateTime.getHours()
  var curMin = curDateTime.getMinutes()
  var curAMPM = " AM"
  var curTime = ""
  if (curHour >= 12){
    curHour -= 12
    curAMPM = " PM"
  }
  if (curHour == 0) curHour = 12
  curTime = curHour + ":" + ((curMin < 10) ? "0" : "") + curMin + curAMPM

  var date = curDateTime.getDate()
  var month = curDateTime.getMonth()
  var year = curDateTime.getYear()
  month = month + 1
  if(year<1000) year+=1900
  $("lastUpdateTime").innerHTML=curTime + " " + month + "/" + date + "/" + year
}


function windowHeight() {
  // Standard browsers (Mozilla, Safari, etc.)
  if (self.innerHeight)
    return self.innerHeight;
  // IE 6
  if (document.documentElement && document.documentElement.clientHeight)
    return document.documentElement.clientHeight;
  // IE 5
  if (document.body)
    return document.body.clientHeight;
  // Just in case. 
  return 0;
}


function handleResize() {
  var height=windowHeight()-$('toolbar').offsetHeight- 30;
  $('map').style.height = height + 'px';
  $('sidebar').style.height = height + 'px';
}

