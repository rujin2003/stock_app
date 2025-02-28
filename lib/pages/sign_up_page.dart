import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Image.asset("assets/icons/auth.png"),
              Text(
                "Register with email",
                style: Theme.of(context).textTheme.displayMedium,
              ),
              Text(
                "Join the community to trade, buy, sell and explore!",
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Gap(24),
              TextFormField(
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.email,
                  ),
                  labelText: "Email",
                ),
              ),
              TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.lock,
                  ),
                  labelText: "Password",
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text("Forgot Password?"),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: 48,
                child: FilledButton(
                  onPressed: () {},
                  child: Text("Login"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
