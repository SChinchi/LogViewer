import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const KEY_USE_CUT_OFF_DATE = 'use_cut_off_date';
  static const KEY_CUT_OFF_DATE = 'cut_off_date';

  static late SharedPreferencesWithCache _prefs;
  static late bool _useCutOffDate;
  static DateTime? _cutOffDate;

  static init() async {
    _prefs = await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions());

    _useCutOffDate = _prefs.getBool(KEY_USE_CUT_OFF_DATE) ?? false;
    if (_useCutOffDate) {
      _cutOffDate = DateTime.tryParse(_prefs.getString(KEY_CUT_OFF_DATE) ?? '');
    }
  }

  static setUseCutOffDate(bool value) async {
    _useCutOffDate = value;
    _prefs.setBool(KEY_USE_CUT_OFF_DATE, value);
  }

  static bool getUseCutOffDate() => _useCutOffDate;

  static setCutOffDate(DateTime? date) async {
    if (date != null) {
      _cutOffDate = date;
      await _prefs.setString(KEY_CUT_OFF_DATE, date.toIso8601String());
    }
  }

  static DateTime? getCutOffDate() => _useCutOffDate ? _cutOffDate : null;

  static getCutOffDateString() {
    if (_cutOffDate != null) {
      var d = _cutOffDate!;
      return '${d.year.toString()}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    }
    return 'N/A';
  }
}