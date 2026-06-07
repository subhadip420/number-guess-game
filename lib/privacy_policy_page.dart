import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Privacy Policy",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Last Updated: June 2026",
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "1. Information Collection",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Number Guess Challenge does not collect, store, or share any personal information directly.",
            ),

            const SizedBox(height: 20),

            const Text(
              "2. Advertisements",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "This app uses Google AdMob to display advertisements. AdMob may collect device information and identifiers to provide personalized or non-personalized ads.",
            ),

            const SizedBox(height: 20),

            const Text(
              "3. Third-Party Services",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "This application uses third-party services including Google AdMob. These services may collect information according to their own privacy policies.",
            ),

            const SizedBox(height: 20),

            const Text(
              "4. Children's Privacy",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "This app is intended for general audiences and does not knowingly collect personal information from children.",
            ),

            const SizedBox(height: 20),

            const Text(
              "5. Contact Us",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const SelectableText(
              "support.sptechstudios@gmail.com",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}