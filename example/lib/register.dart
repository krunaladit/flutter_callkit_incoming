import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  RegisterWidget(this._helper, {Key? key}) : super(key: key);
  @override
  _MyRegisterWidget createState() => _MyRegisterWidget();
}

class _MyRegisterWidget extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _wsUriController = TextEditingController();
  final TextEditingController _sipUriController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _authorizationUserController =
      TextEditingController();
  final Map<String, String> _wsExtraHeaders = {
    // 'Origin': ' https://tryit.jssip.net',
    // 'Host': 'tryit.jssip.net:10443'
  };
  late SharedPreferences _preferences;
  late RegistrationState _registerState;

  SIPUAHelper? get helper => widget._helper;

  @override
  initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _loadSettings();
  }

  @override
  deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
  //  _saveSettings();
  }
  // {
  // "status": true,
  // "message": "Location list",
  // "error": null,
  // "data": [
  // {
  // "public_outbound_number": "8324765379",
  // "sip_user_id": "021-021OwnerVMobile3854",
  // "sip_user_password": "RDJ3YDrFfR44haGT",
  // "aditpbxId": "23",
  // "aditpbx_sip_user": "021-021OwnerVMobile3854",
  // "aditpbx_sip_password": "RDJ3YDrFfR44haGT",
  // "_id": "2707c5e9-f614-4e1a-8a6e-549e8128f0e2",
  // "line_number": "021",
  // "location": {
  // "_id": "b9307cd9-612b-4e90-9a24-60f307a65d8c",
  // "name": "New York"
  // },
  // "location_id": "location|b9307cd9-612b-4e90-9a24-60f307a65d8c",
  // "is_last_used": false,
  // "isCalltracking": true,
  // "te_code": "newyork",
  // "parklines": [
  // "901",
  // "902"
  // ]
  // },
  // {
  // "public_outbound_number": "8325530686",
  // "sip_user_id": "021-021OwnerVMobile2713",
  // "sip_user_password": "PMmHUJajDZ7YT9Wy",
  // "aditpbxId": "525",
  // "aditpbx_sip_user": "021-021OwnerVMobile2713",
  // "aditpbx_sip_password": "PMmHUJajDZ7YT9Wy",
  // "_id": "ad40c2fc-2109-465a-afe9-7eafb9c07bf9",
  // "line_number": "021",
  // "location": {
  // "_id": "c36b7d59-fee8-4b14-a8f2-078c3d70e256",
  // "name": "Pentagon"
  // },
  // "location_id": "location|c36b7d59-fee8-4b14-a8f2-078c3d70e256",
  // "is_last_used": true,
  // "isCalltracking": true,
  // "te_code": "pentagon",
  // "parklines": [
  // "901",
  // "902"
  // ]
  // }
  // ]
  // }
  void _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    var voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    _preferences.setString('voiptoken',voipToken);
    print("VOIP_TOKEN");
    print(voipToken);
    print(_preferences.getString('voiptoken'));
    setState(() {
      _wsUriController.text =
          _preferences.getString('ws_uri') ?? 'wss://wrtcbeta1.adit.com:65089/ws';
      _sipUriController.text =
          _preferences.getString('sip_uri') ?? '021-021OwnerVMobile2713@wrtcbeta1.adit.com';
      _displayNameController.text =
          _preferences.getString('display_name') ?? 'Flutter SIP UA';
      _passwordController.text = _preferences.getString('password') ?? 'PMmHUJajDZ7YT9Wy';
      _authorizationUserController.text =
          _preferences.getString('auth_user') ?? '021-021OwnerVMobile2713';
    });
  }

  // void _saveSettings() {
  //   _preferences.setString('ws_uri', _wsUriController.text);
  //   _preferences.setString('sip_uri', _sipUriController.text);
  //   _preferences.setString('display_name', _displayNameController.text);
  //   _preferences.setString('password', _passwordController.text);
  //   _preferences.setString('auth_user', _authorizationUserController.text);
  // }

  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      _registerState = state;
    });
  }

  void _alert(BuildContext context, String alertFieldName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$alertFieldName is empty'),
          content: Text('Please enter $alertFieldName!'),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSave(BuildContext context) async{
    if (_wsUriController.text == '') {
      _alert(context, "WebSocket URL");
    } else if (_sipUriController.text == '') {
      _alert(context, "SIP URI");
    }
    var voipToken = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
    _preferences.setString('voiptoken',voipToken);
    print("VOIP_TOKEN");
    print(voipToken);
    UaSettings settings = UaSettings();

    settings.webSocketUrl = _wsUriController.text;
    settings.webSocketSettings.extraHeaders = _wsExtraHeaders;
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';

    settings.uri = _sipUriController.text;
    settings.authorizationUser = _authorizationUserController.text;
    settings.password = _passwordController.text;
    settings.displayName = _displayNameController.text;
    settings.userAgent = 'Dart SIP Client v1.0.0';
    settings.dtmfMode = DtmfMode.RFC2833;

    helper!.start(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("SIP Account"),
        ),
        body: Align(
            alignment: Alignment(0, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(48.0, 18.0, 48.0, 18.0),
                        child: Center(
                            child: Text(
                          'Register Status: ${EnumHelper.getName(_registerState.state)}',
                          style: TextStyle(fontSize: 18, color: Colors.black54),
                        )),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 18.0, 48.0, 0),
                        child: Align(
                          child: Text('WebSocket:'),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _wsUriController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          child: Text('SIP URI:'),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _sipUriController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          child: Text('Authorization User:'),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _authorizationUserController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                            hintText: _authorizationUserController.text.isEmpty
                                ? '[Empty]'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          child: Text('Password:'),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _passwordController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                            hintText: _passwordController.text.isEmpty
                                ? '[Empty]'
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(46.0, 18.0, 48.0, 0),
                        child: Align(
                          child: Text('Display Name:'),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 0.0, 48.0, 0),
                        child: TextFormField(
                          controller: _displayNameController,
                          keyboardType: TextInputType.text,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.all(10.0),
                            border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.black12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(0.0, 18.0, 0.0, 0.0),
                      child: Container(
                        height: 48.0,
                        width: 160.0,
                        child: MaterialButton(
                          child: Text(
                            'Register',
                            style:
                                TextStyle(fontSize: 16.0, color: Colors.white),
                          ),
                          color: Colors.blue,
                          textColor: Colors.white,
                          onPressed: () => _handleSave(context),
                        ),
                      ))
                ])));
  }

  @override
  void callStateChanged(Call call, CallState state) {
    //NO OP
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }
}
