import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class WeekStartMaterialLocalizations extends DefaultMaterialLocalizations {
  const WeekStartMaterialLocalizations(this.firstWeekday);

  final int firstWeekday;

  @override
  int get firstDayOfWeekIndex => firstWeekday % 7;
}

class WeekStartLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const WeekStartLocalizationsDelegate(this.firstWeekday);

  final int firstWeekday;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(
        WeekStartMaterialLocalizations(firstWeekday),
      );

  @override
  bool shouldReload(covariant WeekStartLocalizationsDelegate old) =>
      old.firstWeekday != firstWeekday;
}
