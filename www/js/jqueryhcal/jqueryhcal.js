/* CONFIG/ GLOBALS */

var dayNames = new Array("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday");
var dayAbbrevs = new Array("S", "M", "T", "W", "T", "F", "S");
var monthNames = new Array ("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");
var monthLength = new Array(31,28,31,30,31,30,31,31,30,31,30,31);

var firstDayOfWeek = 0;
var DEBUG = 1;
var globalDateHash = new Object();

/************************************** helper functions ************************/
function debug(message) {
  if (DEBUG)
    alert(message);
}

/* Trims the starting zero off of a number to ensure JS gets a regular int, not an octal */
function trimStartingZero(number) {
	number = (number + '');
	if (number.substring(0,1) == "0") {
		number = number.substring(1,number.length)
	}
	return parseInt(number);
}
/* parses datetime */
function parseDT(dt) {
	var dtText;
	var result;
	if ($(dt).attr('title')) {
		dtText = $(dt).attr('title');
	} else {
		dtText = $(dt).children([0]).html();
	}
  	if (dtText != null) {
		result = dtText.match( /^(\d{4})(\d{2})(\d{2})/ );
	}
	if (result == null) {
    	//	debug("didn't recognize DT: " + dtText);
		return
  	}
  	return [result[1], result[2], result[3]];
}

// TODO deal with leap year
getMonthLength = function(year, month) {
  return monthLength[month - 1];
}
/*********************************************************************
**	First: check for abilities and readiness 
**	Second: find events (.vevent), process and add to globalDateHash
**	Third: make month tables and append to page 
**********************************************************************/
function findHCalendarEvents () {
  if (!(document.getElementById && document.createElement)) {
    debug("No DOM!");
    return;
  }
  if ($('#jhCalendar') == null) {  
    debug("jhCalendar not found!")
    return;
  }
 
  $('.vevent').each(function() {
    	var eventHash = {};
  	var startDateInfo;
  	var endDateInfo;
  	eventHash.summary = $(this).find(".summary, :first").html();
 	eventHash.description = $(this).find(".description").html();
 	eventHash.time = $(this).find(".time, :first").html();
	startDateInfo = parseDT($(this).children(".dtstart")); 
	
	endDateInfo = parseDT($(this).children(".dtend"));
	if (endDateInfo == null) {
		endDateInfo = [[startDateInfo[0]],[startDateInfo[1]],[startDateInfo[2]]];
 	}
 	var startDate = startDateInfo[2];
 	var endDate = endDateInfo[2];

	// handle events that span months:
	// If event goes into next month, grab end of this month and add event until then.
	// If event starts in previous month, grab start of month and add event till end date.
	if ((startDateInfo[0] < endDateInfo[0]) || (endDateInfo[0] > endDateInfo[0])
			|| (startDateInfo[1] < endDateInfo[1]) || (endDateInfo[1] > startDateInfo[1])) {
		endDate = getMonthLength(startDateInfo[0], startDateInfo[1]);
		addEventHashToGlobalDateHash(eventHash, startDateInfo, startDate, endDate);
		
		startDate = 1;
		endDate = parseInt(endDateInfo[2]);
		addEventHashToGlobalDateHash(eventHash, endDateInfo, startDate, endDate);
	} 
	//For events that are within a single month, just populate the event days normally.
	else {
		addEventHashToGlobalDateHash(eventHash, startDateInfo, startDate, endDate);
	}
	return;  
  });
 
  for (year in globalDateHash) {
    for (month in globalDateHash[year]) {
      var mt = makeMonthTable(globalDateHash[year][month], year, month);
      $('#jhCalendar').append(mt);
    }
  }
}


/**
 * Adds EventHash Object representing Event Data on a specific Day to the GlobalDateHash Object. 
 * If the startDateDay and endDateDay are not equal, the event will be added to all Days in between.
 */
function addEventHashToGlobalDateHash(eventHash, dateInfo, startDate, endDate) {
	// ParseDT returns an Array with three parts:
	// First [0] is the Year, Second [1] is the Month, Third [2] is the Day. 
	//  If the startDate is not equal to endDate, it's a multi-day event and we must loop through 
	// and add the event for each day in the span globalDateHash.
	for (var i = trimStartingZero(startDate); i <= trimStartingZero(endDate); i++) {
		// If the Year doesn't exist in the globalDateHash, add Object for it.
		if (globalDateHash[ dateInfo[0] ] == null) {
			globalDateHash[ dateInfo[0] ] = new Object();
		}
		// If the Month doesn't exist in the globalDateHash, add Object to represent it.
		if (globalDateHash[ dateInfo[0] ][ dateInfo[1] ] == null) {
			globalDateHash[ dateInfo[0] ][ dateInfo[1] ] = new Object();
		}
		// If the Day doesn't exist in the globaDateHash, add Array to store Events on this day.
		if (globalDateHash[ dateInfo[0] ][ dateInfo[1] ][ i ] == null) {
			globalDateHash[ dateInfo[0] ][ dateInfo[1] ][ i ] = new Array();
		}
		// Add this Event to the Array List of Events for this Day.
		globalDateHash[ dateInfo[0] ][ dateInfo[1] ][ i ].push(eventHash);
	}
}

//Create Table of the specified Month for the specified Year, with events. 
function makeMonthTable (monthHash, year, month) {
  currentMonthLength = getMonthLength(year, month);
  previousMonthLength = getMonthLength(year, month-1);
  var today = new Date;
  var todayYear = today.getFullYear();
  var todayMonth = today.getMonth() + 1;
  var todayDay = today.getDate();    
  var days = new Array(currentMonthLength+1); // We are going to index this array starting at 1.  Because I said so.
  
  // Create an HTML Table to Represent the Month and set necessary Attributes.
  var monthTable =  document.createElement('table');
  $(monthTable).addClass('calTable');
  
 // Create thead with rows for month/year, full day names and abbreviated day names
  var thead = document.createElement("thead");
  $(monthTable).append(thead);

  var titleRow = document.createElement('tr');
  $(thead).append(titleRow)

  var titleTH = document.createElement('th')
  $(titleRow).append($(titleTH).addClass('calHeader').attr("colspan", 7));
  $(titleTH).html(monthNames[trimStartingZero(month)-1] + " " + year);

  
  var headerRow = document.createElement('tr');
	for (var i = 0; i < dayNames.length; i++) {
		$(headerRow).html($(headerRow).html() + '<th scope="col" >' + dayNames[i] + '</th>');
	}
  $(thead).append($(headerRow).addClass('longDays'));

  var abbrevHeaderRow = document.createElement('tr');
	for (var i = 0; i < dayAbbrevs.length; i++) {
		$(abbrevHeaderRow).html($(abbrevHeaderRow).html() + '<th scope="col" >' + dayAbbrevs[i] + '</th>');
	}
  $(thead).append($(abbrevHeaderRow).addClass('abbrevDays'));
  	
  // create tbody and fill with days
  var tbody = document.createElement("tbody");
  $(monthTable).append(tbody);

  for (var i = 1; i <= currentMonthLength; i++) {
    days[i] = document.createElement('td');
    if (todayYear == year && todayMonth == month && todayDay == i) {
      days[i].className += ' calDayToday';
    }
    $(days[i]).append('<div class="calDayLabel">' + i + '</div>');
  }
  
  // populate days here
  
  for (var day in monthHash) {
    var eventString = '';
    for (var i = 0; i < monthHash[day].length; i++) {
      dayTD = days[day-0];
	$(dayTD).addClass('calEventDay');
	eventString += '<p><strong>' + monthHash[day][i].summary + '</strong> ';
	if (monthHash[day][i].description) {
		eventString += monthHash[day][i].description;
	}
	eventString += '</p>';
	$(dayTD).append('<div class="event">' + eventString + '</div>');
    }

  }    
  var dateToCheck = new Date();
  dateToCheck.setYear(year);
  dateToCheck.setDate(1);
  dateToCheck.setMonth(month-1);
  var dayOfFirstOfMonth = dateToCheck.getDay();

  var row = tbody.appendChild(document.createElement("tr"));
  // Loop through empty Days before first Day of Month and fill with 'outOfRange' Cells.
	for (var i = 0; i < dayOfFirstOfMonth; i++) {
		$(row).append('<td class="outOfRange"><div class="calDayLabel"> ' + (previousMonthLength - (dayOfFirstOfMonth - i-1)) + '</div></td>');
	}
  
  for (var i = 1; i <= currentMonthLength; i++) {
    if (row.childNodes.length == 7) {
      row = tbody.appendChild(document.createElement("tr"));
    }
    if(row.childNodes.length == 0 ||row.childNodes.length == 6){
	$(days[i]).addClass('weekend');
	}	
    row.appendChild(days[i]);
  }
  // fill in next month's days to end
  newmonth = 1;
  while (row.childNodes.length < 7) {
      $(row).append('<td class="outOfRange"><div class="calDayLabel">' + newmonth + '</div></td>');
	newmonth++;
  }
  return monthTable;
}

$(document).ready(findHCalendarEvents);
