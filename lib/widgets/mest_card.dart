// lib/widgets/mest_card.dart
import 'package:flutter/material.dart';

class MestCard extends StatelessWidget {
  final String testBasligi;
  final String testResmi;
  final String testId;
  final bool isMe;
  final VoidCallback onTap;

  const MestCard({
    Key? key,
    required this.testBasligi,
    required this.testResmi,
    required this.testId,
    required this.isMe,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 240,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMe ? const Color(0xFFFF5A5F).withOpacity(0.5) : Colors.grey.shade800,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                testResmi,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, error, stack) => Container(
                  height: 120,
                  color: Colors.grey[800],
                  child: const Icon(Icons.image_not_supported, color: Colors.white54),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    testBasligi,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5A5F), Color(0xFFFF8A8F)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        "Mestle!",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}