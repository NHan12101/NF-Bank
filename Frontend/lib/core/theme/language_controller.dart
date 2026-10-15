import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { vi, en }

class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  AppLanguage _language = AppLanguage.vi;

  AppLanguage get language => _language;
  bool get isEnglish => _language == AppLanguage.en;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('APP_LANGUAGE') ?? 'vi';
      _language = langCode == 'en' ? AppLanguage.en : AppLanguage.vi;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    _language = _language == AppLanguage.vi ? AppLanguage.en : AppLanguage.vi;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('APP_LANGUAGE', _language == AppLanguage.en ? 'en' : 'vi');
    } catch (_) {}
  }
}
