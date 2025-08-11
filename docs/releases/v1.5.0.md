# gday-cli v1.5.0 - Health Data Integration & Testing Infrastructure

*Released: August 11, 2025*

## 🎯 Major Features

### 💍 Oura Ring Health Data Integration
- **Complete Oura API v2 integration** with sleep, readiness, and activity data
- **Automatic integration** when `OURA_PAT` environment variable is set
- **Standalone health data viewing** with `--oura` and `--oura-debug` CLI flags

### 😴 Sophisticated Sleep Tracking
- **Multi-source sleep detection algorithm** combining:
  - Activity-based bedtime detection (when movement stopped)
  - Sleep period tracking for actual sleep onset and wake times
  - Raw time calculation from sleep onset to wake time
- **Transparent data source citations** showing which API/method detected each timestamp
- **Sleep stage breakdown** with REM, Light, and Deep sleep percentages inline
- **Robust session grouping** to avoid cross-night confusion

### 🧪 Comprehensive Testing Infrastructure
- **Reorganized test commands**: `npm test` and `npm test:all` run comprehensive suite
- **17 individual tests** across 6 test suites with 100% pass rate
- **Coverage assessment** and detailed test reporting
- **Multiple test types**: unit, integration, BDD, and installation tests

## 📱 User Experience

### Health Data Display
When you have an Oura ring and set your `OURA_PAT` environment variable, gday now shows:

```
- 🥱 you went to bed at 10:30PM (as detected by Oura activity tracking) and
- 😴   went to sleep at 10:45PM (as detected by Oura sleep period tracking) and  
- 🌞    woke up today at 7:17AM (as detected by Oura sleep period tracking)
- 💤      for a total of 8:31 sleep (REM: 15% Light: 66% Deep: 18%)
- 🛌 Sleep score is 80, up from 70 (+26% change from 7-day avg 63)
- 🚥 Readiness is   83, up from 78 (+12% change from 7-day avg 74)
```

### New CLI Commands
- `gday oura` - Show only Oura health data
- `gday --oura` - Show only Oura health data  
- `gday --oura-debug` - Show raw Oura API data for debugging

## 🔧 Technical Improvements

### Sleep Detection Algorithm
- **80+ lines of documentation** explaining multi-source approach
- **Activity pattern analysis** detecting bedtime from movement cessation
- **Session grouping logic** to find coherent sleep periods
- **Time calculation accuracy** matching user's actual experience

### Test Infrastructure  
- **Comprehensive test runner** (`test/test_all.sh`) with coverage assessment
- **API data fixtures** from real Oura responses for reliable testing
- **Multiple test categories**:
  - Unit tests (calendar functions, config validation, Oura algorithms)
  - Integration tests (core functionality)
  - BDD tests (time handling scenarios)
  - Installation tests (package verification)

### Code Quality
- **Humanized data source descriptions** for better user understanding
- **Error handling** for missing credentials and API failures  
- **Modular architecture** with separated concerns (lib/oura.sh)
- **Cross-platform compatibility** maintaining existing macOS/Linux support

## 🚀 Getting Started with Oura Integration

1. **Get your Oura Personal Access Token**: https://cloud.ouraring.com/personal-access-tokens
2. **Set environment variable**: `export OURA_PAT=YOUR_TOKEN_HERE`
3. **Run gday**: Health data will automatically appear alongside your calendar

## 📊 What's Tested

- ✅ Sleep timing algorithms (7 comprehensive tests)
- ✅ Time emoji generation (6 tests with edge cases)  
- ✅ Basic CLI functionality and version verification
- ✅ Integration tests and BDD time handling scenarios
- ⚠️  Config parsing and error handling (skeleton tests for future expansion)

## 🔄 Migration Notes

- **No breaking changes** - existing functionality unchanged
- **Optional integration** - Oura features only activate with `OURA_PAT` set
- **Test command changes**: 
  - `npm test` now runs comprehensive suite (was basic version check)
  - `npm run test:all` runs all tests including installation tests
  - Removed confusing `test:oura` command

## 🐛 Bug Fixes

- Fixed bash nameref compatibility issues with older bash versions
- Improved sleep timing accuracy to match Apple Health data
- Resolved cross-night session confusion in sleep period detection

## 🔮 Future Roadmap

- Apple HealthKit integration for data corroboration
- Additional health metrics (heart rate variability, stress tracking)
- Enhanced config parsing with validation
- Expanded error handling coverage

---

**Full Changelog**: https://github.com/discoveryworks/gday-cli/compare/v1.4.1...v1.5.0

**Installation**: `brew install discoveryworks/gday-cli/gday` or `npm install -g gday-cli`