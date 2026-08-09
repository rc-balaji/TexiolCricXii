import 'package:flutter/widgets.dart';

import '../data/app_store.dart';

class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({required AppStore store, required super.child, super.key})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }

  static AppStore read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }
}
