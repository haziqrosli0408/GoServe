import 'dart:js_interop';

@JS('OneSignal.login')
external void _jsOneSignalLogin(String externalId);

@JS('OneSignal.logout')
external void _jsOneSignalLogout();

@JS('getOneSignalSubscriptionId')
external String? _jsGetSubscriptionId();

void jsOneSignalLogin(String externalId) => _jsOneSignalLogin(externalId);
void jsOneSignalLogout() => _jsOneSignalLogout();
String? jsGetSubscriptionId() => _jsGetSubscriptionId();
