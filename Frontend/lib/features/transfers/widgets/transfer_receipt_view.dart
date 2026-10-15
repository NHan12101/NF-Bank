import 'package:flutter/material.dart';

class BankMark extends StatelessWidget {
  const BankMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF7C83FD), Color(0xFF4FD1C5)],
      ),
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Icon(Icons.north_east_rounded, size: 20, color: Colors.white),
  );
}

class ReceiptHeader extends StatelessWidget {
  const ReceiptHeader({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      BankMark(),
      SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NF BANK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'BIÊN LAI CHUYỂN KHOẢN',
              style: TextStyle(
                color: Color(0xFF7F8BA8),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
          ],
        ),
      ),
      Text(
        'NF • SECURE',
        style: TextStyle(
          color: Color(0xFF68D391),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
      ),
    ],
  );
}

class ReceiptParty extends StatelessWidget {
  const ReceiptParty({
    super.key,
    required this.label,
    required this.name,
    required this.accountNumber,
    required this.avatarURL,
  });

  final String label;
  final String name;
  final String accountNumber;
  final String avatarURL;

  @override
  Widget build(BuildContext context) {
    final normalizedURL = avatarURL.trim();
    final initial = name.trim().isEmpty ? 'N' : name.trim()[0].toUpperCase();
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF7C83FD), width: 1.5),
          ),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFF293352),
            backgroundImage: normalizedURL.startsWith('https://')
                ? NetworkImage(normalizedURL)
                : null,
            child: normalizedURL.startsWith('https://')
                ? null
                : Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFFB7BBFF),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7F8BA8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '$accountNumber · NF Bank',
                style: const TextStyle(color: Color(0xFF9AA6C0), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceiptRow extends StatelessWidget {
  const ReceiptRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF7F8BA8), fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFFDCE2F0),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
