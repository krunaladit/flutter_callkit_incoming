import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';


import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming_example/register.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';

int isDisconnected = 0;

class SipUaHealerCommon implements SipUaHelperListener {
  var ipAddress = "";

  // //Instance of Flutter Connectivity
  // final Connectivity _connectivity = Connectivity();

  //Stream to keep listening to network change state
  late StreamSubscription _streamSubscription;

  static final SipUaHealerCommon _singleton = SipUaHealerCommon._internal();
  SIPUAHelper? _helper = SIPUAHelper();
  webrtc.MediaStream? _localStream;
  Timer? _timer;
  Timer? _timer2;
  Timer? _timer3;
  Timer? _timer4;
  Timer? _timer5;
  Call? _call;
  CallState? _callState;

  //String _incomingNumber = "";
  // String _outGoingNumber = "";
  bool isTransportStateConnected = false;
  bool isSipRegister = false;

  // String _callDirection = "";
  //bool _isCallOnGoing = false;

  //String currentCallId = "";

  // bool get isCallOnGoing => _isCallOnGoing;
  List<TimerModelWithTimer> callTimer = [];

  /// save current call object
  Call? _tempCallForAttendedTransfer;

  String teCode = "";
  List<String> parkLines = [];

  // set isCallOnGoing(bool value) {
  //   _isCallOnGoing = value;
  // }

  // String get callDirection => _callDirection;
  //
  // set callDirection(String value) {
  //   _callDirection = value;
  // }
  //
  // String get incomingNumber => this._incomingNumber;
  //
  // String get outGoingNumber => _outGoingNumber;
  //
  // set outGoingNumber(String value) {
  //   _outGoingNumber = value;
  // }

  bool _isDndOn = false;

  bool get isDndOn => _isDndOn;

  set isDndOn(bool value) {
    _isDndOn = value;
  }

  Call get call => this._call!;

  CallState get callState => this._callState!;

  SIPUAHelper? get helper => this._helper!;

  Call? _call2;

  Call get getCall2 => this._call2!;

  var platform = const MethodChannel('adit');
  late SharedPreferences _preferences;
  factory SipUaHealerCommon() {
    return _singleton;
  }

  SipUaHealerCommon._internal() {
    //_getCallingEvent();
    registerListener();

    // if (Platform.isIOS) {
    //   GetConnectionType();
    //   _streamSubscription =
    //       _connectivity.onConnectivityChanged.listen(_updateState);
    // }
  }
  void postPBXToken () async{
    _preferences = await SharedPreferences.getInstance();
    String token = _preferences.getString('voiptoken')?? "";
    String sipUser = _preferences.getString('auth_user')??"021-021OwnerVMobile2713";
    var data = {
      "token": token,
      "devicetype": "ios",
      "sipuser": sipUser,
      // "environment": kDebugMode ? "debug" : "prod",
      "environment":  "debug" ,
      "sessionAuthorization": "f3635738.b841.4602.9abd.01d3a3664f28",//Add session ID
      "dnd": "off",
    };

    var header = {
      "accept-mobile-api": "aditapp-mobile-api",
      "cookie": "s%3ATwGK-ypFf36Hn4AK08gcfgJxbxYrc38Z.zXBSwNMcSD15V3ApSD7eEM171mY00OxKoZliYKBs9rk",
      "authorization": "f3635738.b841.4602.9abd.01d3a3664f28",
    };

//https://betatelephony-manager.aditadv.xyz/pbx/proxyapi.php?key=ZNmuP3wMJqsXujtN
    //var url = Uri.https('https://betamobileapi.adit.com', '/pbx/proxyapi.php?key=ZNmuP3wMJqsXujtN');
    //   var url = Uri.parse("https://betatelephony-manager.aditadv.xyz/pbx/proxyapi.php?key=ZNmuP3wMJqsXujtN");
    // print(url);
    print(data);

    var response = await dio.post('https://betamobileapi.adit.com/bridge/mobiletokensave', data: data,options: Options(headers: header));


    if (response.statusCode == 200) {
      print('Response body: ${response}');
      print(response.data.toString());

    }
    print('Response status: ${response.statusCode}');

  }
  Future<String> activeCalls(String uid) async {
    String phone = "";
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        // print("CHECK FOR UID $uid");
        // print('DATA of Active Call====>: $calls');
        // print('CALL LENGTH+++++++++++++++++${calls.length}');
        // for(var data in calls){
        //   print("CALL ID IN ACTIVE CALLS ++++++++++");
        //   print(data['id']);
        // }
        bool isExist = calls.any((element) =>
            element["id"].toString().toLowerCase() == uid.toLowerCase());
        if (isExist) {
          var call = calls.firstWhere((element) =>
              element["id"].toString().toLowerCase() == uid.toLowerCase());
          phone = call["handle"];
        }
      }
    }
    return phone;
  }

  // a method to get which connection result, if you we connected to internet or no if yes then which network
  // Future<void> GetConnectionType() async {
  //   var connectivityResult;
  //   // try {
  //   //   connectivityResult = await (_connectivity.checkConnectivity());
  //   // } on PlatformException catch (e) {
  //   //   print(e);
  //   // }
  //
  //   return _updateState(connectivityResult);
  // }

  // state update, of network, if you are connected to WIFI connectionType will get set to 1,
  // and update the state to the consumer of that variable.
  // _updateState(ConnectivityResult result) async {
  //   print("CONNECTIVTY CHANGE====");
  //   print(result);
  //
  //   switch (result) {
  //     case ConnectivityResult.wifi:
  //       if (Platform.isIOS) {
  //         bool isPbxLogIn = await Prefs.getBoolF(CM.PREF_IS_PBX_LOG_IN);
  //         await Ipify.ipv4().then((ipv4) {
  //           print(ipv4);
  //           if (ipv4 != ipAddress && isPbxLogIn) {
  //             ipAddress = ipv4;
  //             SipUaHealerCommon().registerUser(isIpChanged: true);
  //           }
  //         });
  //       }
  //
  //       break;
  //     case ConnectivityResult.mobile:
  //       if (Platform.isIOS) {
  //         bool isPbxLogIn = await Prefs.getBoolF(CM.PREF_IS_PBX_LOG_IN);
  //         await Ipify.ipv4().then((ipv4) {
  //           print(ipv4);
  //           if (ipv4 != ipAddress && isPbxLogIn) {
  //             ipAddress = ipv4;
  //             SipUaHealerCommon().registerUser(isIpChanged: true);
  //           }
  //         });
  //       }
  //
  //       break;
  //     case ConnectivityResult.none:
  //       break;
  //     default:
  //       Get.snackbar('Network Error', 'Failed to get Network Status');
  //       break;
  //   }
  // }

  Future<String> initCurrentCall() async {
    //check current call from pushkit if possible
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        print('DATA: $calls');
        // _currentUuid = calls[0]['id'];
        return calls[0]['id'];
      } else {
        //_currentUuid = "";
        return "";
      }
    }
    return "";
  }

  // Future<void> endCurrentCall(
  //   String number,
  //   String displayName,
  // ) async {
  //   /// remove call from callkit
  //
  //   number = call.direction == CM.INCOMING
  //       ? Utils().getNumberWithPrefixOnIncoming(displayName, number)
  //       : number;
  //   CallEventController callEventController = Get.find();
  //   if (callEventController.callkitCalls.length > 0) {
  //     if (callEventController.callkitCalls
  //         .any((element) => element.number == number)) {
  //       String callId = callEventController.callkitCalls
  //               .firstWhere((element) => element.number == number)
  //               .uuId ??
  //           "";
  //       await FlutterCallkitIncoming.endCall(callId);
  //     }
  //   } else {
  //     //  await FlutterCallkitIncoming.endAllCalls();
  //   }
  //   callEventController.removeDataForCallkit(number);
  // }

  @override
  void callStateChanged(Call call, CallState callState) async {
    // TODO: implement callStateChanged
    // print("CALL ID:::=======>: ${call.id}");
    // await activeCalls();

    /// all call states
    /// call state Initiation then show notification
    print("callState: ${callState.state.name}");
    this._call = call;
    if (callState.state != CallStateEnum.STREAM) {
      this._callState = callState;
      //callStateStream.add(callState);


    // if (callState.state != CallStateEnum.STREAM) {
    //   this._callState = callState;
    //   callStateStream.add(callState);
    // }
    // if (_call != null && _call!.direction == "INCOMING") {
    //   _incomingNumber =
    //       getFormattedNumber(_call?.session.remote_identity?.uri!.user ?? "");
    //
    //   _callDirection = "INCOMING";
    }

    switch (callState.state) {
      case CallStateEnum.NONE:
      case CallStateEnum.CALL_INITIATION:
        break;
      case CallStateEnum.STREAM:
        handelStreams(callState);
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        // if (isDndOn && call.direction == CM.INCOMING) {
        //   print("------DND ON-------");
        //   return;
        // }
        bool isAny = callTimer.any((element) => element._callerId == call.id);
        if (isAny) {
          callTimer
              .firstWhere((element) => element._callerId == call.id)
              .timeObj!
              .cancel();
          callTimer
              .firstWhere((element) => element._callerId == call.id)
              .timeObj = null;
        }

        // reAssignCalls(call.id ?? "");
        //
        // //Utils().removeOverLay();
        // endCurrentCall(
        //   getFormattedNumber(call.session.remote_identity?.uri?.user ?? ""),
        //   call.remote_display_name ?? "",
        // );
        // callTime = "";
        // if (_timer != null) {
        //   _timer?.cancel();
        // }
        //_isCallOnGoing = false;
        // callTimeStream.add("");
        cleanUp();
        //_call = null;
        // _callState = null;
        break;
      case CallStateEnum.UNMUTED:
        break;
      case CallStateEnum.MUTED:
        break;
      case CallStateEnum.CONNECTING:

      case CallStateEnum.PROGRESS:
        break;
      case CallStateEnum.ACCEPTED:
        //_isCallOnGoing = true;
        // currentCallId = call.id ?? "";
    //    Utils().stopRingTone();
        //
        // if (_timer == null) {
        //   _startTimer(call.id ?? "");
        //   startEventTimer();
        // } else if (_timer2 == null) {
        //   _startTimer2(call.id ?? "");
        // } else if (_timer3 == null) {
        //   _startTimer3(call.id ?? "");
        // } else if (_timer4 == null) {
        //   _startTimer4(call.id ?? "");
        // } else if (_timer5 == null) {
        //   _startTimer5(call.id ?? "");
        // }
        // sendCurrentCallerId(currentCallId);
        break;
      case CallStateEnum.CONFIRMED:
        //currentCallId = call.id ?? "";

        // if (call.direction != CM.INCOMING) {
        //   platform.invokeMethod("call_confirm");
        // }

        break;
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.REFER:
        break;
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // TODO: implement onNewMessage
  }

  @override
  void onNewNotify(Notify ntf) {
    // TODO: implement onNewNotify

  }

  @override
  void registrationStateChanged(RegistrationState state) {
    // print("registrationStateChanged ${state.cause}");
    //  CommonMethods.showSnackbar("Alert", "Register State: ${state.state.toString()}");

      if (state.state == RegistrationStateEnum.REGISTERED) {
        // FlutterCallkitIncoming.sendRegistrationStatus("REGISTERED");
        postPBXToken();
        isSipRegister = true;

      } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
        //FlutterCallkitIncoming.sendRegistrationStatus("REGISTRATION_FAILED");
        isSipRegister = false;

      } else if (state.state == RegistrationStateEnum.NONE) {
        //   FlutterCallkitIncoming.sendRegistrationStatus("NONE");
        isSipRegister = false;
      } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
        //  FlutterCallkitIncoming.sendRegistrationStatus("UNREGISTERED");
        isSipRegister = false;
      }

    // TODO: implement registrationStateChanged
  }

  @override
  void transportStateChanged(TransportState state) {
    // TODO: implement transportStateChanged
    // print("Transport state changed");
    // print(state.state);
    // print(state.cause);
    // CommonMethods.showSnackbar("title", "State ${state.state}");
    // CommonMethods.showSnackbar("title", "Cause ${state.cause}");
    if (state.state == TransportStateEnum.DISCONNECTED && isDisconnected == 0) {
      isDisconnected++;
      // CommonMethods.hideLoader();
      // CommonMethods.showSnackbar("title", "Please try again after sometime");
      isTransportStateConnected = false;
    } else if (state.state == TransportStateEnum.CONNECTED) {
      isTransportStateConnected = true;
    } else {
      isTransportStateConnected = false;
    }
  }

  /// register lister
  void registerListener() async{
    try {
      helper!.addSipUaHelperListener(this);
    } catch (e) {
      print("registerListener error ${e}");
    }
  }

  /// register lister
  void removeListener() {
    try {
      helper!.removeSipUaHelperListener(this);
    } catch (e) {
      print("registerListener error ${e}");
    }
  }

  ///For iOS
  registerUser({bool? isKillSate = false, bool isIpChanged = false}) async {
    try {
      // CommonMethods.printLog(helper!.registered);

      if (helper!.registered && isIpChanged == false) {
        if (kDebugMode) {
          // CommonMethods.showSnackbar("title", "Already Register");
        }
        return true;
      }

      if (isIpChanged == true) {
        // CommonMethods.showSnackbar("Alert", "IP Change call");
        unRegisterUser();
        _helper!.stop();
        removeListener();
        registerListener();
      }

      UaSettings settings = UaSettings();
      // ActiveLocationsController _locationController = Get.find();
      String userId = "021-021OwnerVMobile2713";
      // String password = await Prefs.getStringF(CM.PREF_PBX_PWD);
      // teCode = await Prefs.getStringF(CM.PREF_PBX_TE_CODE);
      // parkLines = await Prefs.getStringListF(CM.PREF_PBX_PARK_LINES);
      // String voipDeviceToken =
      //     await Prefs.getStringF(CM.PREF_VOIP_DEVICE_TOKEN_IOS);
      // String androidDeviceToken = await Prefs.getStringF(CM.PREF_DEVICE_TOKEN);
      //
      // String permission =
      //     await Prefs.getStringF(CM.PREF_NOTIFICATION_PERMISSION);
      // String deviceType = Platform.isAndroid ? "android" : "ios";
      // print("DeviceType isAndroid--->: ${Platform.isAndroid}");
      // var headerObj = {
      //   "token": Platform.isAndroid ? androidDeviceToken : voipDeviceToken,
      //   "deviceType": deviceType,
      //   "permission": "$permission"
      // };
      // await _locationController.reqSaveTokenToPBX(
      //     Platform.isAndroid ? androidDeviceToken : voipDeviceToken,
      //     "granted",
      //     deviceType);
      String webSocketURI = "@wrtcbeta1.adit.com";
      String id = Uri.encodeComponent(userId);
      // settings.webSocketUrl = CM.WebSocketUrl;
      settings.webSocketUrl = "wss://wrtcbeta1.adit.com:65089/ws";
      settings.webSocketSettings.extraHeaders = {};
      //settings.registerParams.extraContactUriParams = headerObj;
      settings.webSocketSettings.allowBadCertificate = true;
      settings.uri = "$id$webSocketURI"; //""113-gunjan@wrtcbeta2.adit.com";
      settings.authorizationUser = "021-021OwnerVMobile2713"; // "113-gunjan";
      // settings.displayName = "Flutter SIP UA";
      settings.password = "PMmHUJajDZ7YT9Wy"; //"8eR6dKfDLFyEvWY5";
      settings.userAgent = 'sip-mobile-sdk-ios';
      settings.register_expires = 86400;
      settings.dtmfMode = DtmfMode.RFC2833;
      settings.maxCallLimit = 2;

      /// start event listener
      // CommonMethods.printLog(
      //     "register start Time ${DateTime.now().millisecondsSinceEpoch}");
      _helper!.start(settings);
    } catch (e) {
      print(e);
      if (kDebugMode) {
        // CommonMethods.showSnackbar("title", "unregisterUser in background");
      }
    }
  }

  void unRegisterUser() {
    if (_helper != null) {
      if (_helper!.registered) {
        _helper!.unregister(false);
      }
    }
  }

// var callTime = "00:00";
//
// void _startTimer() {
//   try {
//     if (_timer != null) {
//       _timer?.cancel();
//       callTimeStream.add("");
//     }
//     _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
//       Duration duration = Duration(seconds: timer.tick);
//       callTime = [duration.inMinutes, duration.inSeconds]
//           .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
//           .join(':');
//       callTimeStream.add(callTime);
//     });
//   } catch (e) {
//     print(e);
//   }
// }

  /// handel call accept
// void handleAccept() async {
//   try {
//     if (call != null) {
//       bool remoteHasVideo = call.remote_has_video;
//       final mediaConstraints = <String, dynamic>{
//         'audio': true,
//         'video': remoteHasVideo
//       };
//       webrtc.MediaStream mediaStream;
//
//       mediaConstraints['video'] = remoteHasVideo;
//       mediaStream =
//           await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
//
//       call.answer(helper!.buildCallOptions(!remoteHasVideo),
//           mediaStream: mediaStream);
//     } else {
//       print("call object null");
//     }
//   } catch (e) {
//     print("call object null");
//     print(e);
//   }
// }

  void handleAccept(String callerId) async {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null) {
      bool remoteHasVideo = tempCall.remote_has_video;
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': remoteHasVideo
      };
      webrtc.MediaStream mediaStream;

      mediaConstraints['video'] = remoteHasVideo;
      mediaStream =
          await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);

      tempCall.answer(_helper!.buildCallOptions(!remoteHasVideo),
          mediaStream: mediaStream);
      _call = tempCall;
    } else {
      if (_call != null) {
        bool remoteHasVideo = call.remote_has_video;
        final mediaConstraints = <String, dynamic>{
          'audio': true,
          'video': remoteHasVideo
        };
        webrtc.MediaStream mediaStream;

        mediaConstraints['video'] = remoteHasVideo;
        mediaStream =
            await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);

        call.answer(_helper!.buildCallOptions(!remoteHasVideo),
            mediaStream: mediaStream);
      } else {
        print("call object null");
      }
    }
  }

// void handleHangup() {
//   if (_call != null) {
//     _call?.hangup();
//   } else {
//     print("call object null");
//   }
// }

// void handleHangup(String callerId) {
//   Call? tempCall = helper!.findCall(callerId);
//
//   if (tempCall != null) {
//     print("_handleHangup 211");
//     bool remoteHasVideo = tempCall.remote_has_video ?? false;
//     tempCall.hangup(_helper!.buildCallOptions(!remoteHasVideo));
//     _call = tempCall;
//   } else {
//     if (_call != null) {
//       print("_handleHangup 211");
//       bool remoteHasVideo = _call?.remote_has_video ?? false;
//       _call?.hangup(_helper!.buildCallOptions(!remoteHasVideo));
//     } else {
//       print("call object null");
//     }
//   }
// }

  void handleHangup(String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null &&
        tempCall.state != CallStateEnum.ENDED &&
        tempCall.state != CallStateEnum.FAILED) {
      print("_handleHangup Line 619");
      bool remoteHasVideo = tempCall.remote_has_video;
      tempCall.hangup(_helper!.buildCallOptions(!remoteHasVideo));
      _call = tempCall;
    } else {
      if (_call != null &&
          _call?.state != CallStateEnum.ENDED &&
          _call!.state != CallStateEnum.FAILED) {
        print("_handleHangup Line 625");
        bool remoteHasVideo = _call?.remote_has_video ?? false;
        _call?.hangup(_helper!.buildCallOptions(!remoteHasVideo));
      } else {
        print("call object null");
      }
    }
  }

// void handleReject() {
//   if (_call != null) {
//     print("_handleHangup 325");
//     _call?.hangup({'status_code': 486});
//   } else {
//     print("call object null");
//   }
// }

  void handleReject(String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null &&
        tempCall.state != CallStateEnum.ENDED &&
        tempCall.state != CallStateEnum.FAILED) {
      print("_handleHangup 396");
      tempCall.hangup({'status_code': 486});
      _call = tempCall;
    } else {
      if (_call != null &&
          _call?.state != CallStateEnum.ENDED &&
          _call!.state != CallStateEnum.FAILED) {
        print("_handleHangup 396");
        _call?.hangup({'status_code': 486});
      } else {
        print("call object null");
      }
    }
  }

  void _handleHangupOnDnd(Call call) {
    if (call != null &&
        call.state != CallStateEnum.ENDED &&
        call.state != CallStateEnum.FAILED) {
      print("_handleHangup 334");

      call.hangup({'status_code': 480});
    } else {
      print("call object null");
    }
  }

// void handleHold(bool isHold) {
//   if (_call != null) {
//     if (!isHold) {
//       call.hold();
//     } else {
//       call.unhold();
//     }
//   }
// }

  void handleHold(bool isHold, String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null) {
      print("isHold ${isHold}");
      if (!isHold) {
        tempCall.hold();
      } else {
        tempCall.unhold();
      }
      _call = tempCall;
    } else {
      if (_call != null) {
        print("isHold ${isHold}");
        if (!isHold) {
          _call?.hold();
        } else {
          _call?.unhold();
        }
      }
    }
  }

  void toggleSpeaker(bool isSpeaker) {
    if (_localStream != null) {
      print("_toggleSpeaker");
      _localStream!.getAudioTracks()[0].enableSpeakerphone(!isSpeaker);
    }
  }

// void muteAudio(bool isMute) {
//   if (_call != null) {
//     print("_muteAudio ${isMute}");
//     if (isMute) {
//       call.mute(true, false);
//     }
//     if (!isMute) {
//       call.unmute(true, false);
//     }
//   } else {}
// }

  void muteAudio(bool isMute, String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null) {
      if (isMute) {
        tempCall.mute(true, false);
      }
      if (!isMute) {
        tempCall.unmute(true, false);
      }
      _call = tempCall;
    } else {
      if (_call != null) {
        print("_muteAudio ${isMute}");
        if (isMute) {
          _call?.mute(true, false);
        }
        if (!isMute) {
          _call?.unmute(true, false);
        }
      } else {}
    }
  }

  void handelStreams(CallState event) async {
    webrtc.MediaStream? stream = event.stream;
    if (event.originator == 'local') {
      event.stream?.getAudioTracks().first.enableSpeakerphone(false);
      _localStream = stream;
    }
  }

  void handleDtmf(String tone) async {
    print('Dtmf tone => $tone');
    if (_call != null) {
      call.sendDTMF(tone);
    }
  }

  void cleanUp() {
    if (_localStream == null) return;
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream!.dispose();
    _localStream = null;
  }

  handleOutGoingCall(String number) async {
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};

    webrtc.MediaStream mediaStream;

    mediaConstraints['video'] = false;
    mediaStream =
        await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);

    helper!.call(number, voiceonly: true, mediaStream: mediaStream);
  }

// handleSecondOutGoingCall(String number) async {
//   handleHold(false);
//
//   _call2 = _call;
//
//   String outGoingNumber = number;
//   print("Outgoing number ===> $number");
//   final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};
//
//   webrtc.MediaStream mediaStream;
//
//   mediaConstraints['video'] = false;
//   mediaStream =
//       await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
//
//   helper!.call(outGoingNumber, voiceonly: true, mediaStream: mediaStream);
// }

// handleAttendedCall() async {
//   var localObj = getCall2;
//   var opt = {
//     'replaces': localObj.session,
//     'mediaConstraints': {'audio': true, 'video': false},
//     'mediaStream': _localStream
//   };
//   _call?.session.refer(localObj.remote_identity, opt);
//   handleHold(true);
// }

// handleCallCutMoveToFirstCall() async {
//   handleHangup();
//   _call = getCall2;
//   handleHold(true);
// }

  handelCallTransfer(String number) {
    if (_call != null) {
      call.refer(number);
    }
  }

  handelCallParking(String number) {
    if (_call != null) {
      call.refer(number, tag: "PARK");
    }
  }

  handelBlindTransfer(String number) async {
    if (_call != null) {
      print("handelBlindTransfer $number");
      _call?.refer(number, tag: "BLIND_TRANSFER");
    }
  }

  var callTime = "00:00";
  var callTime2 = "00:00";
  var callTime3 = "00:00";
  var callTime4 = "00:00";
  var callTime5 = "00:00";

  void _startTimer(String callerId) {
    try {
      if (_timer != null) {
        _timer?.cancel();
        callTime = "";
        //  callTimeStream.add("");
      }
      _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
        Duration duration = Duration(seconds: timer.tick);
        callTime = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');

        String caller = callerId;

        bool isAny = callTimer.any((element) => element._callerId == caller);
        if (!isAny) {
          callTimer.add(TimerModelWithTimer(
              callerId: caller, timer: callTime, timeObj: _timer));
        } else {
          callTimer
              .firstWhere((element) => element._callerId == caller)
              ._timer = callTime;
        }
        //callTimer.add(TimerModel(callerId: caller, timer: callTime));
        //print("Timer 1: ${callTime}");
      });
    } catch (e) {
      print(e);
    }
  }

  void _startTimer2(String callerId) {
    try {
      if (_timer2 != null) {
        _timer2?.cancel();
        callTime2 = "";
        //  callTimeStream.add("");
      }
      _timer2 = Timer.periodic(Duration(seconds: 1), (Timer timer) {
        Duration duration = Duration(seconds: timer.tick);
        callTime2 = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
        // print("Timer 2: ${callTime2}");
        String caller = callerId;

        bool isAny = callTimer.any((element) => element._callerId == caller);
        if (!isAny) {
          callTimer.add(TimerModelWithTimer(
              callerId: caller, timer: callTime2, timeObj: _timer2));
        } else {
          callTimer
              .firstWhere((element) => element._callerId == caller)
              ._timer = callTime2;
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _startTimer3(String callerId) {
    try {
      if (_timer3 != null) {
        _timer3?.cancel();
        callTime3 = "";
        //  callTimeStream.add("");
      }
      _timer3 = Timer.periodic(Duration(seconds: 1), (Timer timer) {
        Duration duration = Duration(seconds: timer.tick);
        callTime3 = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
        // print("Timer 2: ${callTime2}");
        String caller = callerId;

        bool isAny = callTimer.any((element) => element._callerId == caller);
        if (!isAny) {
          callTimer.add(TimerModelWithTimer(
              callerId: caller, timer: callTime3, timeObj: _timer3));
        } else {
          callTimer
              .firstWhere((element) => element._callerId == caller)
              ._timer = callTime3;
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _startTimer4(String callerId) {
    try {
      if (_timer4 != null) {
        _timer4?.cancel();
        callTime4 = "";
        //  callTimeStream.add("");
      }
      _timer4 = Timer.periodic(Duration(seconds: 1), (Timer timer) {
        Duration duration = Duration(seconds: timer.tick);
        callTime4 = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
        // print("Timer 2: ${callTime2}");
        String caller = callerId;

        bool isAny = callTimer.any((element) => element._callerId == caller);
        if (!isAny) {
          callTimer.add(TimerModelWithTimer(
              callerId: caller, timer: callTime4, timeObj: _timer4));
        } else {
          callTimer
              .firstWhere((element) => element._callerId == caller)
              ._timer = callTime4;
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _startTimer5(String callerId) {
    try {
      if (_timer5 != null) {
        _timer5?.cancel();
        callTime5 = "";
        //  callTimeStream.add("");
      }
      _timer5 = Timer.periodic(Duration(seconds: 1), (Timer timer) {
        Duration duration = Duration(seconds: timer.tick);
        callTime5 = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
        // print("Timer 2: ${callTime2}");
        String caller = callerId;

        bool isAny = callTimer.any((element) => element._callerId == caller);
        if (!isAny) {
          callTimer.add(TimerModelWithTimer(
              callerId: caller, timer: callTime5, timeObj: _timer5));
        } else {
          callTimer
              .firstWhere((element) => element._callerId == caller)
              ._timer = callTime5;
        }
      });
    } catch (e) {
      print(e);
    }
  }

  Timer? countdownTimerForEvent;

  stopEventTimer() {
    if (countdownTimerForEvent != null && countdownTimerForEvent!.isActive) {
      countdownTimerForEvent!.cancel();
      countdownTimerForEvent = null;
      callTimer.clear();
    }
  }


  handleAttemptedCall(String number, String callerId) async {
    handleHold(false, callerId);

    _tempCallForAttendedTransfer = _call;

    String outGoingNumber = number;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};

    webrtc.MediaStream mediaStream;

    mediaConstraints['video'] = false;
    mediaStream =
        await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);

    helper?.call(outGoingNumber, voiceonly: true, mediaStream: mediaStream);
  }

  void handleHangupFromListing(String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null) {
      print("handleHangupFromListing 878");
      bool remoteHasVideo = tempCall.remote_has_video;
      tempCall.hangup(_helper!.buildCallOptions(!remoteHasVideo));
    } else {
      if (_call != null) {
        print("handleHangupFromListing 883");
        bool remoteHasVideo = _call?.remote_has_video ?? false;
        _call?.hangup(_helper!.buildCallOptions(!remoteHasVideo));
      } else {
        print("call object null");
      }
    }
  }

  handleSecondAddCall(String number, String callerId) async {
    handleHold(false, callerId);

    _tempCallForAttendedTransfer = _call;

    String outGoingNumber = number;
    final mediaConstraints = <String, dynamic>{'audio': true, 'video': false};

    webrtc.MediaStream mediaStream;

    mediaConstraints['video'] = false;
    mediaStream =
        await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);

    helper?.call(outGoingNumber, voiceonly: true, mediaStream: mediaStream);
  }

  handleCompleteTransfer(String callerId) async {
    var call1 = _tempCallForAttendedTransfer;
    // var opt = {
    //   'replaces': call1!.session,
    //   'mediaConstraints': {'audio': true, 'video': false},
    //   'mediaStream': _localStream
    // };
    // _call?.session.refer(call1.remote_identity, opt);

    var opt = {
      'replaces': _call!.session,
      'mediaConstraints': {'audio': true, 'video': false},
      'mediaStream': _localStream
    };
    // var datata = call1!.session.refer(_call!.remote_identity, opt);
    call1!.refer(_call!.remote_identity ?? "",
        options: opt, tag: "COMPLETE_TRANSFER");
    //_handleHold(true, callerId);
  }

  // handleAttendedCall() async {
  //   var localObj = getCall2;
  //   var opt = {
  //     'replaces': localObj.session,
  //     'mediaConstraints': {'audio': true, 'video': false},
  //     'mediaStream': _localStream
  //   };
  //   _call?.session.refer(localObj.remote_identity, opt);
  //   handleHold(true);
  // }

  void handleCallSwitch(String callerId) {
    Call? tempCall = helper!.findCall(callerId);

    if (tempCall != null) {
      print("_handleCurrentCallHoldMoveToCurrent 926");
      handleHold(false, "");
      _call = tempCall;
      handleHold(true, callerId);

      // sendCurrentCallerId(callerId, _call?.remote_display_name ?? "");
    } else {
      /// no call to move to current
    }
  }

  mergeCall() {}

  void doSubscribeForParkLine() {
    if (parkLines.length > 0) {
      for (var line in parkLines) {
        _helper?.subscribe(
            "${line}-${teCode}", "presence", "application/pidf+xml");
      }
    }
  }

}

class TimerModelWithTimer {
  String? _callerId;
  String? _timer;
  Timer? _timeObj;

  Timer? get timeObj => _timeObj;

  set timeObj(Timer? value) {
    _timeObj = value;
  }

  TimerModelWithTimer({String? callerId, String? timer, Timer? timeObj}) {
    if (callerId != null) {
      this._callerId = callerId;
    }
    if (timer != null) {
      this._timer = timer;
    }
    if (timeObj != null) {
      this._timeObj = timeObj;
    }
  }

  String? get callerId => _callerId;

  set callerId(String? callerId) => _callerId = callerId;

  String? get timer => _timer;

  set timer(String? timer) => _timer = timer;

  TimerModelWithTimer.fromJson(Map<String, dynamic> json) {
    _callerId = json['callerId'];
    _timer = json['Timer'];
    _timeObj = json['timeObj'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['callerId'] = this._callerId;
    data['Timer'] = this._timer;
    data['timeObj'] = this._timeObj;
    return data;
  }
}
