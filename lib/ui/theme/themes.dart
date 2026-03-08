import 'package:flutter/material.dart';
import 'package:iseefortune_flutter/ui/theme/default_theme.dart';

class ThemeProvider extends ChangeNotifier {
  //ThemeData _theme = DarkMidnightTheme.data;
  ThemeData _theme = DefaultTheme.data;
  ThemeData get theme => _theme;

  void setTheme(ThemeData newTheme) {
    _theme = newTheme;
    notifyListeners();
  }
}
