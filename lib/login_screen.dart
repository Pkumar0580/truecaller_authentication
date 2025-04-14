import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:truecaller_sdk/truecaller_sdk.dart';
import 'package:uuid/uuid.dart';

class MobileNumberInputScreen extends StatefulWidget {
  const MobileNumberInputScreen({super.key});

  @override
  State<MobileNumberInputScreen> createState() =>
      _MobileNumberInputScreenState();
}

class _MobileNumberInputScreenState extends State<MobileNumberInputScreen> {
  final TextEditingController _controller = TextEditingController();

  StreamSubscription? _streamSubscription;
  String? codeVerifier;
  late String oAuthState;

  @override
  void initState() {
    super.initState();
    initializeTruecallerSDK(); // popup launch hote hi
  }

  void initializeTruecallerSDK() {
    TcSdk.initializeSDK(
      sdkOption: TcSdkOptions.OPTION_VERIFY_ALL_USERS,
      // buttonColor: 0xFFD0F0C0,
      buttonShapeOption: TcSdkOptions.BUTTON_SHAPE_RECTANGLE,
      // buttonTextColor: 0xFF90EE90
    );

    TcSdk.isOAuthFlowUsable.then((isUsable) {
      if (isUsable) {
        oAuthState = const Uuid().v4();
        log("authState=>$oAuthState");
        TcSdk.setOAuthState(oAuthState);
        TcSdk.setOAuthScopes(['profile', 'phone', 'openid', 'email']);

        TcSdk.generateRandomCodeVerifier.then((codeVerifier) {
          TcSdk.generateCodeChallenge(codeVerifier).then((codeChallenge) {
            if (codeChallenge != null) {
              this.codeVerifier = codeVerifier;
              TcSdk.setCodeChallenge(codeChallenge);
              TcSdk.getAuthorizationCode(); // triggers the popup
            } else {
              setState(() {
                // _showManualInput = true;
              });
            }
          });
        });
      } else {
        setState(() {
          // _showManualInput = true;
        });
      }
    });

    // _streamSubscription = TcSdk.streamCallbackData.listen((tcSdkCallback) {
    //   log('Login Success!');
    //   log('User Data: ${tcSdkCallback.accessToken}');
    //   switch (tcSdkCallback.result) {
    //     case TcSdkCallbackResult.success:
    //       Navigator.pushReplacement(
    //         context,
    //         MaterialPageRoute(builder: (_) => HomeScreen()),
    //       );
    //       break;
    //     case TcSdkCallbackResult.failure:
    //     case TcSdkCallbackResult.verification:
    //     default:
    //       setState(() {
    //         // _showManualInput = true; // show input field if truecaller fails or dismissed
    //       });
    //   }
    // });

    _streamSubscription = TcSdk.streamCallbackData.listen((tcSdkCallback) {
      if (tcSdkCallback.result == TcSdkCallbackResult.success &&
          tcSdkCallback.tcOAuthData != null) {
        final user = tcSdkCallback.tcOAuthData!;
        final authCode = user.authorizationCode;
        exchangeCodeForToken(authCode);
        log('AuthCode: ${user.authorizationCode}');
      } else {
        log('Truecaller popup cancelled or failed');
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Enter Mobile Number")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Mobile Number",
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              log("Entered number: ${_controller.text}");
              // Aapka OTP login ya backend call yahaan se start hoga
            },
            child: Text("Continue"),
          ),
        ]),
      ),
    );
  }

  Future<void> exchangeCodeForToken(String authorizationCode) async {
    final tokenUrl = 'https://oauth-account-noneu.truecaller.com/v1/token';
    final clientId = 'xq6eakxsxuoquh7hzp7lxjd39ana0ovotc1l9jao3w0';

    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': authorizationCode,
          'code_verifier': codeVerifier!,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        String accessToken = tokenData['access_token'];
        log("accessToken:==>> $accessToken");
        fetchUserDetails(accessToken); // Fetch user details using token
      } else {
        log('Error: ${response.statusCode}');
      }
    } catch (e) {
      log("Error exchanging code for token: $e");
    }
  }

  Future<void> fetchUserDetails(String accessToken) async {
    final url = 'https://oauth-account-noneu.truecaller.com/v1/userinfo';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);

        log("data=$userData");
        log("User Name: ${userData['given_name']} ${userData['family_name']}");
        log("Email: ${userData['email'] ?? 'N/A'}");
        log("Phone: ${userData['phone_number']}");
      } else {
        log('Error fetching user details: ${response.statusCode}');
      }
    } catch (e) {
      log('Error fetching user details: $e');
    }
  }
}
