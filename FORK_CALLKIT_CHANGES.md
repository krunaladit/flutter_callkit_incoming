# flutter_callkit_incoming Fork Changes

> **Fork**: https://github.com/malavadit/flutter_callkit_incoming.git
> **Branch**: `feb26-update`
> **Purpose**: Add `CXCallEndedReason` support to `endCall` API so cancel pushes can show "Answered on Another Device" vs "Call Ended" in CallKit.

---

## Why

The server sends a `reason` field in cancel push payloads:
- `"caller_cancelled"` — caller hung up before answer
- `"answered_elsewhere"` — another device of the same user answered

The plugin's `saveEndCall()` method already maps integer reason codes to `CXCallEndedReason`, but the Dart `endCall()` API had no way to pass a reason through. These changes wire it up.

---

## File 1: `lib/flutter_callkit_incoming.dart`

### Change: Add optional `endCallReason` parameter to `endCall`

**Before:**
```dart
static Future endCall(String id) async {
    await _channel.invokeMethod("endCall", {'id': id});
}
```

**After:**
```dart
/// [endCallReason] optional reason for ending the call (iOS only):
///   1 = failed, 2 = remoteEnded, 3 = unanswered,
///   4 = answeredElsewhere, 5 = declinedElsewhere
static Future endCall(String id, {int? endCallReason}) async {
    final args = <String, dynamic>{'id': id};
    if (endCallReason != null) {
      args['endCallReason'] = endCallReason;
    }
    await _channel.invokeMethod("endCall", args);
}
```

- Fully backward-compatible: existing calls without `endCallReason` work unchanged.
- Android ignores the parameter (no CXCallEndedReason on Android).

---

## File 2: `ios/Classes/SwiftFlutterCallkitIncomingPlugin.swift`

### Change: Read `endCallReason` in the `"endCall"` method channel handler and call `saveEndCall()` before `endCall()`

**Before:**
```swift
case "endCall":
    guard let args = call.arguments else {
        result("OK")
        return
    }
    if(self.isFromPushKit){
        self.endCall(self.data!)
    }else{
        if let getArgs = args as? [String: Any] {
            self.data = Data(args: getArgs)
            self.endCall(self.data!)
        }
    }
    result("OK")
    break
```

**After:**
```swift
case "endCall":
    guard let args = call.arguments else {
        result("OK")
        return
    }
    if(self.isFromPushKit){
        if let getArgs = args as? [String: Any],
           let reason = getArgs["endCallReason"] as? Int {
            self.saveEndCall(self.data!.uuid, reason)
        }
        self.endCall(self.data!)
    }else{
        if let getArgs = args as? [String: Any] {
            self.data = Data(args: getArgs)
            if let reason = getArgs["endCallReason"] as? Int {
                self.saveEndCall(self.data!.uuid, reason)
            }
            self.endCall(self.data!)
        }
    }
    result("OK")
    break
```

- When `endCallReason` is present: calls `saveEndCall(uuid, reason)` which uses `CXProvider.reportCall(with:endedAt:reason:)` to tell CallKit the specific end reason.
- When `endCallReason` is absent: no change in behavior, `saveEndCall` is not called.
- The existing `saveEndCall()` method (already in the plugin) handles the mapping:

| Code | CXCallEndedReason |
|------|-------------------|
| 1 | `.failed` |
| 2 | `.remoteEnded` |
| 3 | `.unanswered` |
| 4 | `.answeredElsewhere` |
| 5 | `.declinedElsewhere` |

---

## No Android Changes Required

The Android side of `flutter_callkit_incoming` does not use `CXCallEndedReason` (iOS-only concept). The optional Dart parameter is simply ignored on Android.

---

## How The App Uses It

In `AppDelegate.swift`, the cancel push handler:
1. Reads `reason` from the push payload
2. Maps `"answered_elsewhere"` to `4`, `"caller_cancelled"` to `2`
3. Calls `saveEndCall(cancelId, endCallReason)` before ending the call

This results in:
- **Caller cancelled** -> iOS shows "Call Ended"
- **Answered elsewhere** -> iOS shows "Answered on Another Device"
