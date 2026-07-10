import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// A stateful wrapper that provides [AppLocalizations] to the entire widget tree.
class LanguageProvider extends StatefulWidget {
  final Widget child;

  const LanguageProvider({super.key, required this.child});

  static _LanguageProviderState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_LanguageProviderState>();
    assert(state != null, 'LanguageProvider not found in widget tree');
    return state!;
  }

  @override
  State<LanguageProvider> createState() => _LanguageProviderState();
}

class _LanguageProviderState extends State<LanguageProvider> {
  AppLanguage _language = AppLanguage.englishRomanUrdu;

  AppLocalizations get loc => AppLocalizations(_language);
  AppLanguage get language => _language;
  bool get isUrdu => _language == AppLanguage.urdu;

  void setLanguage(AppLanguage lang) {
    setState(() {
      _language = lang;
    });
  }

  /// Convenience: convert dropdown string to enum
  void setLanguageFromString(String value) {
    switch (value) {
      case 'اردو':
        setLanguage(AppLanguage.urdu);
        break;
      case 'English':
        setLanguage(AppLanguage.english);
        break;
      default:
        setLanguage(AppLanguage.englishRomanUrdu);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LanguageInherited(
      loc: loc,
      isUrdu: isUrdu,
      child: widget.child,
    );
  }
}

/// InheritedWidget so descendants can access localization via context.
class _LanguageInherited extends InheritedWidget {
  final AppLocalizations loc;
  final bool isUrdu;

  const _LanguageInherited({
    required this.loc,
    required this.isUrdu,
    required super.child,
  });

  static _LanguageInherited? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_LanguageInherited>();
  }

  @override
  bool updateShouldNotify(_LanguageInherited oldWidget) {
    return loc.language != oldWidget.loc.language;
  }
}

/// Extension on BuildContext for easy access.
extension LanguageContext on BuildContext {
  AppLocalizations get loc {
    final inherited = _LanguageInherited.maybeOf(this);
    return inherited?.loc ?? AppLocalizations(AppLanguage.englishRomanUrdu);
  }

  bool get isUrdu {
    final inherited = _LanguageInherited.maybeOf(this);
    return inherited?.isUrdu ?? false;
  }
}
