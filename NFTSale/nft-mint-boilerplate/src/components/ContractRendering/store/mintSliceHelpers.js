export const getCurrentTier = (tiers) => {
  // Takes a list of tiers, and returns the current tier based on current
  // time and the tier start and end times.

  // Get the current time
  var now = new Date();
  var earliest = new Date();

  if (!tiers) {
    return {
      'status': 'final',
      'start-time': { time: now.toISOString() },
      'end-time': { time: earliest.toISOString() },
      cost: -1,
    };
  }

  // Loop through the tiers and find the current one
  for (var i = 0; i < tiers.length; i++) {
    var tier = tiers[i];
    var start = new Date(tier['start-time']['time']);
    if (i === 0) {
      earliest = start;
    }
    var end = new Date(tier['end-time']['time']);

    if (start < earliest) {
      earliest = start;
    }

    // If the start is the same as the end, then we just check if now is after
    // the start time
    if (start.getTime() === end.getTime() && now >= start) {
      return {
        ...tier,
        'status': 'final',
      }
    }
    else if (now >= start && now <= end) {
      return {
        ...tier,
        'status': 'during',
      }
    }
  }
  
  // If we get here, then we are not in any tier
  var status = 'before';
  if (now > earliest) {
    status = 'inactive';
  }
  return {
    'status': status,
    'start-time': { time: now.toISOString() },
    'end-time': { time: earliest.toISOString() },
    cost: -1,
  };
}

export const formatCountdown = (end) => {
  var diff = end - Date.now();

  var msec = diff;
  var dd = Math.floor(msec / 1000 / 60 / 60 / 24);
  msec -= dd * 1000 * 60 * 60 * 24;
  var hh = Math.floor(msec / 1000 / 60 / 60);
  msec -= hh * 1000 * 60 * 60;
  var mm = Math.floor(msec / 1000 / 60);
  msec -= mm * 1000 * 60;
  var ss = Math.floor(msec / 1000);
  msec -= ss * 1000;

  return {
    days: dd,
    hours: hh,
    minutes: mm,
    seconds: ss,
  }
}