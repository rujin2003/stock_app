import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Generates a 5-letter display ID from a UUID
/// This is used only for display purposes, the original UUID should be used for backend operations
String generateShortId(String uuid) {
  // Remove hyphens from UUID and convert to lowercase
  final cleanUuid = uuid.replaceAll('-', '').toLowerCase();
  
  // Generate SHA-256 hash of the UUID
  final bytes = utf8.encode(cleanUuid);
  final hash = sha256.convert(bytes);
  
  // Convert hash to base36 (alphanumeric) and take first 5 characters
  final hashInt = BigInt.parse(hash.toString(), radix: 16);
  final base36 = hashInt.toRadixString(36);
  
  // Ensure we always return exactly 5 characters
  return base36.substring(0, 5).toUpperCase();
}

/// Example usage:
/// String uuid = '123e4567-e89b-12d3-a456-426614174000';
/// String shortId = generateShortId(uuid); // Returns something like "A1B2C" 