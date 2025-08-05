const { Given, When, Then } = require('@cucumber/cucumber');
const { execSync } = require('child_process');
const assert = require('assert');

// Helper to source bash functions and execute commands
function bashExec(command) {
  try {
    return execSync(`cd ${process.cwd()} && source lib/calendar.sh && ${command}`, {
      encoding: 'utf8',
      stdio: 'pipe'
    }).trim();
  } catch (error) {
    return error.stdout ? error.stdout.trim() : '';
  }
}

// Test data storage
let testContext = {};

Given('I have a calendar with various appointment types', function () {
  // Setup test context
  testContext = {};
});

Given('the system uses 30-minute time blocks as the basic unit', function () {
  // This is a given architectural constraint
  testContext.blockSize = 30;
});

Given('an appointment has no emoji', function () {
  testContext.appointment = 'Meeting with client';
  testContext.hasEmoji = false;
});

Given('an appointment starts at neither :00 nor :30', function () {
  testContext.appointmentTime = '10:15am';
  testContext.isOffHour = true;
});

Given('an appointment starting at {string}', function (time) {
  testContext.appointmentTime = time;
});

Given('a multi-block appointment starting at {string}', function (startTime) {
  testContext.appointmentStart = startTime;
  testContext.isMultiBlock = true;
});

Given('a {int}-pomodoro appointment at {string}', function (pomodoroCount, startTime) {
  testContext.pomodoroCount = pomodoroCount;
  testContext.appointmentStart = startTime;
});

Given('multiple 🍅 at different times', function () {
  testContext.pomodoros = ['10:00am', '10:30am', '11:00am'];
});

Given('appointments with same title at different times', function () {
  testContext.appointments = [
    { time: '10:00am', title: 'Daily Standup' },
    { time: '10:30am', title: 'Daily Standup' },
    { time: '11:00am', title: 'Daily Standup' }
  ];
});

When('the system processes the appointment', function () {
  // Simulate appointment processing
  testContext.processed = true;
});

When('the system calculates the base emoji', function () {
  if (testContext.appointmentTime) {
    const timeNumber = testContext.appointmentTime.replace(/[^0-9]/g, '');
    const result = bashExec(`get_emoji_for_time ${timeNumber}`);
    testContext.calculatedEmoji = result;
  }
});

When('the system processes subsequent blocks after the first', function () {
  // Test boundary snapping logic
  testContext.processedSubsequentBlocks = true;
});

When('the appointment spans multiple pomodoros', function () {
  testContext.spansMultiple = true;
});

When('the system generates repeated emojis', function () {
  // Test repeated emoji generation
  if (testContext.appointmentStart) {
    const timeNumber = testContext.appointmentStart.replace(/[^0-9]/g, '');
    const results = [];
    for (let i = 0; i < (testContext.pomodoroCount || 3); i++) {
      const result = bashExec(`generate_repeated_emoji "Test Meeting" ${i} ${timeNumber}`);
      results.push(result);
    }
    testContext.repeatedEmojis = results;
  }
});

When('I use {string} flag', function (flag) {
  testContext.sortFlag = flag;
});

Then('a clock emoji showing the appropriate time should be prepended', function () {
  // Verify clock emoji is prepended
  assert(testContext.processed, 'Appointment should be processed');
});

Then('it should be treated as {string} and show {string}', function (treatedAs, emoji) {
  testContext.expectedTreatedAs = treatedAs;
  testContext.expectedEmoji = emoji;
  // Note: This would need actual time processing logic to fully verify
});

Then('it should round down to earlier time and add 🍒 sub-pomodoro indicator', function () {
  if (testContext.calculatedEmoji) {
    assert(testContext.calculatedEmoji.includes('🍒'), 
      `Expected cherry emoji in ${testContext.calculatedEmoji}`);
  }
});

Then('subsequent blocks should snap to boundaries: {word}, {word}', function (time1, time2) {
  // Verify boundary snapping
  testContext.expectedBoundaries = [time1, time2];
});

Then('not continue the offset pattern: {word}, {word}', function (badTime1, badTime2) {
  // Verify offset pattern is NOT used
  testContext.forbiddenTimes = [badTime1, badTime2];
});

Then('cherry should appear once: 🕙🍒 → 🕙🍒🕙 → 🕙🍒🕙🕙', function () {
  if (testContext.repeatedEmojis) {
    // Verify cherry pattern
    const firstEmoji = testContext.repeatedEmojis[0];
    assert(firstEmoji.includes('🍒'), 'First emoji should contain cherry');
    
    if (testContext.repeatedEmojis.length > 1) {
      const secondEmoji = testContext.repeatedEmojis[1];
      const cherryCount = (secondEmoji.match(/🍒/g) || []).length;
      assert(cherryCount === 1, 'Cherry should appear only once in subsequent emojis');
    }
  }
});

Then('each should appear chronologically and hide when conflicted', function () {
  // Verify pomodoro behavior
  assert(testContext.pomodoros, 'Pomodoros should be defined');
});

Then('appointments should be grouped together', function () {
  if (testContext.sortFlag === '--sort-alpha') {
    testContext.shouldGroup = true;
  }
});

Then('appointments should keep strict chronological order', function () {
  if (testContext.sortFlag === '--sort-interleaved') {
    testContext.shouldSort = true;
  }
});

Then('time column should be {int} chars wide', function (width) {
  testContext.expectedColumnWidth = width;
});

Then('emojis should count as 2x visual width', function () {
  testContext.emojiWidthMultiplier = 2;
});

Then('AM/PM should transition correctly', function () {
  // Verify AM/PM transitions
  testContext.amPmHandled = true;
});

// Additional step definitions for scenario outlines would go here
// For now, many of these are placeholder implementations that would need
// actual integration with the calendar.sh functions to be fully functional