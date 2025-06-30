import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/models/auth_state.dart';
import 'package:stock_app/providers/auth_state_provider.dart';


class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true); // Show loading state

      await ref
          .read(authStateNotifierProvider.notifier)
          .signUp(_emailController.text, _passwordController.text);

      setState(() => _isLoading = false); // Hide loading state
      
      // Navigation is now handled by the router's redirect logic
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateNotifierProvider);

    // Show error if there's an error message
    if (authState.status == AuthStatus.error &&
        authState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authStateNotifierProvider.notifier).clearError();
      });
    }

    // Navigate back to login if registration is successful
    if (authState.status == AuthStatus.unauthenticated &&
        (authState.errorMessage?.contains("Registration successful") ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: Colors.green,
          ),
        );

        // Show verification email sent message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification email has been sent to your email."),
            backgroundColor: Colors.blue,
          ),
        );

        // Navigate to sign in page
        context.go('/');

        // Clear message so it doesn't trigger again
        ref.read(authStateNotifierProvider.notifier).clearError();
      });
    }

    // Set loading state
    _isLoading = authState.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(title: Text("Sign Up")),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset("assets/icons/auth.png", height: 100),
                Text(
                  "Register with email",
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  "Join the community to trade, buy, sell, and explore!",
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                ),
                Gap(24),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email),
                    labelText: "Email",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                Gap(12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock),
                    labelText: "Password",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                Gap(12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock),
                    labelText: "Confirm Password",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _signUp,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text("Register"),
                  ),
                ),
                Gap(12),
                Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text("or sign up with"),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                Gap(12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => ref
                            .read(authStateNotifierProvider.notifier)
                            .signInWithGoogle(),
                    icon: Image.asset(
                      "assets/icons/google.png",
                      height: 24,
                    ),
                    label: Text("Continue with Google"),
                  ),
                ),
                Gap(12),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?"),
                        TextButton(

                     
                          onPressed: () => context.go('/signin'),
                          child: const Text('Sign in'),
                        ),
                      ],
                    ),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
