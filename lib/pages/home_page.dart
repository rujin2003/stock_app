import 'package:flutter/material.dart';
import 'package:stock_app/pages/auth_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
            if (constraints.maxWidth > 900) {
              return Center(
                child: SizedBox(
                  height: constraints.maxHeight * 0.7,
                  width: constraints.maxWidth * 0.4,
                  child: AuthPage(
                    constraints: constraints,
                  ),
                ),
              );
            }
            return AuthPage(
              constraints: constraints,
            );
          },
        ),
      ),
    );
  }
}
