import 'package:flutter/material.dart';
import 'package:stock_app/pages/sign_in_page.dart';
import 'package:stock_app/pages/sign_up_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.constraints});

  final BoxConstraints constraints;

  @override
  AuthPageState createState() => AuthPageState();
}

class AuthPageState extends State<AuthPage> {
  bool showSignIn = true;

  void toggleView() {
    setState(() {
      showSignIn = !showSignIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
              decoration: widget.constraints.maxWidth > 900
                  ? BoxDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(20),
                      ),
                      color: Colors.transparent,
                      border: Border.all(
                        color: Colors.black26,
                        width: 2,
                      ),
                    )
                  : null,
              child: showSignIn ? SignInPage() : SignUpPage()),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(showSignIn
                  ? "Don't have an account? "
                  : "Already have an account? "),
              TextButton(
                onPressed: toggleView,
                child: Text(
                  showSignIn ? 'Sign up' : 'Sign in',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
