import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';

class WhatsAppResult {
  final bool success;
  final String message;
  final String? errorDetails;

  WhatsAppResult({
    required this.success,
    required this.message,
    this.errorDetails,
  });
}

class WhatsAppService {
  static final WhatsAppService instance = WhatsAppService._internal();
  WhatsAppService._internal();

  /// Send password recovery or custom message via Super Admin configured WhatsApp API Gateway
  Future<WhatsAppResult> sendPasswordRecovery({
    required String targetPhone,
    required String userName,
    required String userEmail,
    required String password,
    String? overrideApiUrl,
    String? overrideApiKey,
    String? overrideTemplate,
  }) async {
    final supabase = SupabaseService.instance;
    final apiUrl = (overrideApiUrl ?? await supabase.fetchAppSetting('whatsapp_api_url'))?.trim();
    final apiKey = (overrideApiKey ?? await supabase.fetchAppSetting('whatsapp_api_key'))?.trim() ?? '';
    final template = (overrideTemplate ?? await supabase.fetchAppSetting('whatsapp_template'))?.trim() ??
        'Hello {name}, your TYM Habit Tracker password is: {password}';

    if (apiUrl == null || apiUrl.isEmpty) {
      return WhatsAppResult(
        success: false,
        message: 'WhatsApp API Gateway URL is not configured in Super Admin Dashboard.',
        errorDetails: 'Missing whatsapp_api_url setting.',
      );
    }

    // Clean Phone number (e.g. 9876543210 -> 919876543210)
    final cleanDigits = targetPhone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanDigits.length == 10 ? '91$cleanDigits' : cleanDigits;

    // Prepare message text from template
    final messageText = template
        .replaceAll('{name}', userName)
        .replaceAll('{password}', password)
        .replaceAll('{phone}', formattedPhone)
        .replaceAll('{email}', userEmail);

    final isGetRequest = apiUrl.contains('?') || apiUrl.contains('{phone}') || apiUrl.contains('{message}') || apiUrl.contains('{text}');

    // Format GET URL string if applicable
    String formattedUrl = apiUrl
        .replaceAll('{phone}', formattedPhone)
        .replaceAll('{number}', formattedPhone)
        .replaceAll('{to}', formattedPhone)
        .replaceAll('{key}', Uri.encodeComponent(apiKey))
        .replaceAll('{token}', Uri.encodeComponent(apiKey))
        .replaceAll('{apikey}', Uri.encodeComponent(apiKey))
        .replaceAll('{password}', Uri.encodeComponent(password))
        .replaceAll('{name}', Uri.encodeComponent(userName))
        .replaceAll('{email}', Uri.encodeComponent(userEmail))
        .replaceAll('{message}', Uri.encodeComponent(messageText))
        .replaceAll('{text}', Uri.encodeComponent(messageText))
        .replaceAll('{body}', Uri.encodeComponent(messageText));

    if (isGetRequest) {
      if (!formattedUrl.contains(formattedPhone)) {
        formattedUrl += (formattedUrl.contains('?') ? '&' : '?') + 'phone=$formattedPhone';
      }
      if (!formattedUrl.contains(Uri.encodeComponent(messageText)) && !formattedUrl.contains('text=')) {
        formattedUrl += '&text=${Uri.encodeComponent(messageText)}';
      }
      if (apiKey.isNotEmpty && !formattedUrl.contains(Uri.encodeComponent(apiKey)) && !formattedUrl.contains('apikey=')) {
        formattedUrl += '&apikey=${Uri.encodeComponent(apiKey)}';
      }
    }

    final uri = Uri.parse(formattedUrl);

    try {
      if (isGetRequest) {
        debugPrint('Executing WhatsApp API GET Request: $uri');

        final headers = <String, String>{
          'Accept': 'application/json, text/plain, */*',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          if (apiKey.isNotEmpty) 'x-api-key': apiKey,
        };

        final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return WhatsAppResult(
            success: true,
            message: 'WhatsApp message sent successfully to +$formattedPhone!',
            errorDetails: 'HTTP ${response.statusCode}: ${response.body}',
          );
        } else {
          return WhatsAppResult(
            success: false,
            message: 'WhatsApp Gateway API returned error (HTTP ${response.statusCode}).',
            errorDetails: 'Status ${response.statusCode}: ${response.body}',
          );
        }
      } else {
        // Execute POST JSON Request
        debugPrint('Executing WhatsApp API POST Request: $uri');

        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          if (apiKey.isNotEmpty) 'x-api-key': apiKey,
        };

        final body = jsonEncode({
          'phone': formattedPhone,
          'to': formattedPhone,
          'number': formattedPhone,
          'receiver': formattedPhone,
          'message': messageText,
          'text': messageText,
          'body': messageText,
          if (apiKey.isNotEmpty) 'key': apiKey,
          if (apiKey.isNotEmpty) 'token': apiKey,
          if (apiKey.isNotEmpty) 'api_key': apiKey,
        });

        final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 8));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return WhatsAppResult(
            success: true,
            message: 'WhatsApp message sent successfully to +$formattedPhone!',
            errorDetails: 'HTTP ${response.statusCode}: ${response.body}',
          );
        } else {
          return WhatsAppResult(
            success: false,
            message: 'WhatsApp Gateway API returned error (HTTP ${response.statusCode}).',
            errorDetails: 'Status ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      final errStr = e.toString();
      debugPrint('WhatsApp API Direct Fetch Exception: $errStr');

      // If browser CORS blocked direct HTTP fetch (Failed to fetch), trigger external window/URL launch fallback!
      if (errStr.contains('Failed to fetch') || errStr.contains('ClientException') || errStr.contains('XMLHttpRequest')) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return WhatsAppResult(
              success: true,
              message: 'Dispatched via Gateway Trigger to +$formattedPhone!',
              errorDetails: 'Bypassed browser CORS restriction by launching endpoint directly: $formattedUrl',
            );
          }
        } catch (launchErr) {
          debugPrint('Launch URL fallback error: $launchErr');
        }
      }

      return WhatsAppResult(
        success: false,
        message: 'Could not connect to WhatsApp API Gateway.',
        errorDetails: '$errStr\n(Note: Ensure your Gateway API URL accepts browser requests or supports CORS).',
      );
    }
  }
}
