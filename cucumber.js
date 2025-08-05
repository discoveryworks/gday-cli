module.exports = {
  default: {
    require: ['features/step_definitions/*.js'],
    format: ['progress', 'json:reports/cucumber-report.json'],
    formatOptions: {
      snippetInterface: 'async-await'
    },
    publishQuiet: true
  }
};