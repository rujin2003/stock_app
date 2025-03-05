import 'package:flutter/material.dart';
import 'package:stock_app/pages/sign_in_page.dart';
import 'package:stock_app/pages/sign_up_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final authContent = _buildAuthContent(constraints);

            if (constraints.maxWidth > 900) {
              return Center(
                child: SizedBox(
                  height: constraints.maxHeight * 0.7,
                  width: constraints.maxWidth * 0.4,
                  child: authContent,
                ),
              );
            }
            return authContent;
          },
        ),
      ),
    );
  }

  Widget _buildAuthContent(BoxConstraints constraints) {
    return Column(
      children: [
        Expanded(
          child: Container(
              decoration: constraints.maxWidth > 900
                  ? BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                      color: Colors.transparent,
                      border: Border.all(
                        color: Colors.black26,
                        width: 2,
                      ),
                    )
                  : null,
              child: showSignIn ? const SignInPage() : const SignUpPage()),
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
