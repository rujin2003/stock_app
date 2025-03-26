import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:path/path.dart' as path;

class UserVerificationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadDocument(
      File file, String userId, String documentType) async {
    try {
      final fileExt = path.extension(file.path);
      final fileName = '${userId}_${documentType.toLowerCase()}$fileExt';
      final storageResponse = await _client.storage
          .from('verification_documents')
          .upload(fileName, file);

      final fileUrl =
          _client.storage.from('verification_documents').getPublicUrl(fileName);

      developer.log('Document uploaded successfully',
          name: 'VerificationService');
      return fileUrl;
    } catch (e) {
      developer.log('Error uploading document: $e',
          name: 'VerificationService');
      rethrow;
    }
  }

  Future<void> submitVerification(
      String userId, String documentType, String documentUrl) async {
    try {
      await _client.from('user_verifications').upsert({
        'user_id': userId,
        'document_type': documentType,
        'document_url': documentUrl,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      });

      developer.log('Verification submitted successfully',
          name: 'VerificationService');
    } catch (e) {
      developer.log('Error submitting verification: $e',
          name: 'VerificationService');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getVerificationStatus(String userId) async {
    try {
      final response = await _client
          .from('user_verifications')
          .select()
          .eq('user_id', userId)
          .single();
      return response;
    } catch (e) {
      developer.log('Error fetching verification status: $e',
          name: 'VerificationService');
      return null;
    }
  }
}
