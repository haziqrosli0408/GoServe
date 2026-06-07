import 'dart:js_interop';

@JS('OneSignal.login')
external void _jsOneSignalLogin(String externalId);

@JS('osLogout')
external void _jsOneSignalLogout();

@JS('osPromptPush')
external void _jsOneSignalPromptPush();

@JS('getOneSignalSubscriptionId')
external String? _jsGetSubscriptionId();

void jsOneSignalLogin(String externalId) => _jsOneSignalLogin(externalId);
void jsOneSignalLogout() => _jsOneSignalLogout();
void jsOneSignalPromptPush() => _jsOneSignalPromptPush();
String? jsGetSubscriptionId() => _jsGetSubscriptionId();
