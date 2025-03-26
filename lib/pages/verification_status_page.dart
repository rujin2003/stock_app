import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

class VerificationStatusPage extends ConsumerWidget {
  const VerificationStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = _buildContent(context);

            if (constraints.maxWidth > 900) {
              return Center(
                child: SizedBox(
                  height: constraints.maxHeight * 0.6,
                  width: constraints.maxWidth * 0.4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border.all(
                        color: Colors.black26,
                        width: 2,
                      ),
                    ),
                    child: content,
                  ),
                ),
              );
            }
            return content;
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Verification in Progress",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Gap(16),
              Text(
                "We're reviewing your documents. This usually takes 1-2 business days.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Gap(32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
