import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'jws_lease_verifier.dart';
import 'premium_config.dart';
import 'premium_entitlement.dart';
import 'premium_entitlement_manager.dart';
import 'premium_product.dart';
import 'purchase_verifier.dart';

/// HTTP response abstraction for testing and transport decoupling.
class HttpResponseData {
  final int statusCode;
  final String body;

  const HttpResponseData({
    required this.statusCode,
    required this.body,
  });
}

/// Abstract transport for executing HTTP requests to the verification backend.
abstract class HttpTransport {
  Future<HttpResponseData> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  });
}

/// Production [HttpTransport] implementation using [dart:io] [HttpClient].
class DefaultHttpTransport implements HttpTransport {
  final HttpClient _client;

  DefaultHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  @override
  Future<HttpResponseData> post({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final request = await _client.postUrl(url).timeout(timeout);
    headers.forEach((key, value) {
      request.headers.set(key, value);
    });
    request.add(utf8.encode(body));
    final response = await request.close().timeout(timeout);
    final responseBody = await response.transform(utf8.decoder).join();
    return HttpResponseData(
      statusCode: response.statusCode,
      body: responseBody,
    );
  }
}

/// RemotePurchaseVerifier — Authoritative backend-driven purchase verifier
/// implementing BUG-001 Option A security contract.
///
/// Features:
/// - Extracts authentic Google Play purchase token from [PurchaseDetails.verificationData]
/// - Dispatches authoritative verification request to Cloudflare Workers backend
/// - Cryptographically verifies the Ed25519-signed compact JWS lease via [JwsLeaseVerifier]
/// - Authoritatively updates [PremiumEntitlementManager] with the verified 7-day lease
/// - Authoritatively revokes entitlement when backend reports 403 REVOKED
/// - Treats network errors / 5xx as non-fatal without erroneously revoking valid offline leases
/// - Fails closed when backend is unconfigured in release mode or when fallback is disabled
class RemotePurchaseVerifier implements PurchaseVerifier {
  final PremiumEntitlementManager? _entitlementManager;
  final HttpTransport _transport;
  final JwsLeaseVerifier _leaseVerifier;
  final PurchaseVerifier? _fallbackVerifier;
  final String _issuerUrl;
  final bool _allowUnconfiguredFallback;
  final bool _isReleaseMode;

  RemotePurchaseVerifier({
    PremiumEntitlementManager? entitlementManager,
    HttpTransport? transport,
    JwsLeaseVerifier? leaseVerifier,
    PurchaseVerifier? fallbackVerifier,
    String? issuerUrl,
    bool? allowUnconfiguredFallback,
    bool? isReleaseMode,
  })  : _entitlementManager = entitlementManager,
        _transport = transport ?? DefaultHttpTransport(),
        _leaseVerifier = leaseVerifier ?? const JwsLeaseVerifier(),
        _fallbackVerifier = fallbackVerifier ?? const DefaultPurchaseVerifier(),
        _issuerUrl = issuerUrl ?? PremiumBackendConfig.issuerUrl,
        _allowUnconfiguredFallback = allowUnconfiguredFallback ?? !kReleaseMode,
        _isReleaseMode = isReleaseMode ?? kReleaseMode;

  @override
  Future<PremiumEntitlement?> verifyPurchase(PurchaseDetails purchaseDetails) async {
    // 1. Strict Product ID validation
    if (purchaseDetails.productID != premiumLifetimeProductId) {
      if (kDebugMode) {
        print('REMOTE VERIFIER [Rejected]: Product mismatch: ${purchaseDetails.productID}');
      }
      return null;
    }

    // 2. Fail closed if backend URL is unconfigured
    // In release mode or whenever unconfigured fallback is disabled (default),
    // an unconfigured backend MUST NEVER grant Premium through client-only verification.
    final effectiveIssuerUrl = _issuerUrl;
    if (effectiveIssuerUrl.isEmpty) {
      if (_isReleaseMode || !_allowUnconfiguredFallback || _fallbackVerifier == null) {
        if (kDebugMode) {
          print('REMOTE VERIFIER [Fail-Closed]: Backend is unconfigured and fallback is disabled/in release mode. Failing closed.');
        }
        return null;
      }
      return _fallbackVerifier!.verifyPurchase(purchaseDetails);
    }

    // 3. Extract authentic Google Play purchase token
    final purchaseToken = _extractPurchaseToken(purchaseDetails);
    if (purchaseToken == null || purchaseToken.isEmpty) {
      if (kDebugMode) {
        print('REMOTE VERIFIER [Rejected]: Missing purchase token in transaction data.');
      }
      return null;
    }

    // 4. Resolve Store Source
    final StoreSource storeSource;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      storeSource = StoreSource.google;
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      storeSource = StoreSource.apple;
    } else {
      storeSource = StoreSource.unknown;
    }

    // 5. Query Authoritative Backend Worker
    final verifyUri = Uri.parse('$effectiveIssuerUrl/verify-purchase');
    final requestPayload = jsonEncode({
      'purchase_token': purchaseToken,
      'package_name': PremiumBackendConfig.expectedAudience,
      'product_id': purchaseDetails.productID,
    });

    try {
      final response = await _transport.post(
        url: verifyUri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestPayload,
        timeout: const Duration(seconds: 10),
      );

      // Handle Authoritative Revocation (HTTP 403 Forbidden)
      // Rule: Only an explicitly recognized authoritative revocation response triggers immediate revocation.
      // A generic HTTP 403, gateway error, WAF denial, malformed response, or unrelated error payload
      // MUST NEVER revoke an existing Premium entitlement.
      if (response.statusCode == 403) {
        bool isAuthoritativeRevocation = false;
        try {
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final status = decoded['status'];
            final reason = decoded['reason'];
            if (status == 'REVOKED' && reason == 'GOOGLE_PLAY_CANCELLED') {
              isAuthoritativeRevocation = true;
            }
          }
        } catch (_) {
          isAuthoritativeRevocation = false;
        }

        if (isAuthoritativeRevocation) {
          if (kDebugMode) {
            print('REMOTE VERIFIER [Revoked]: Backend authoritatively confirmed purchase is cancelled/revoked.');
          }
          if (_entitlementManager != null) {
            await _entitlementManager!.invalidateEntitlement(status: EntitlementStatus.revoked);
          }
          return PremiumEntitlement(
            status: EntitlementStatus.revoked,
            productId: purchaseDetails.productID,
            storeSource: storeSource,
            verifiedAt: DateTime.now().toUtc(),
            transactionReference: purchaseDetails.purchaseID,
          );
        } else {
          // Generic 403, WAF block, proxy block, or unexpected body
          if (kDebugMode) {
            print('REMOTE VERIFIER [Warning]: Non-authoritative HTTP 403 received. Entitlement will NOT be revoked.');
          }
          return null;
        }
      }

      // Handle Successful Verification with Signed Lease (HTTP 200 OK)
      if (response.statusCode == 200) {
        Map<String, dynamic> responseJson;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            return null;
          }
          responseJson = decoded;
        } catch (_) {
          return null;
        }

        final String? jwsToken = responseJson['token'] as String? ?? responseJson['lease_token'] as String?;

        if (jwsToken == null || jwsToken.isEmpty) {
          if (kDebugMode) {
            print('REMOTE VERIFIER [Error]: 200 OK missing lease token in response.');
          }
          return null;
        }

        // Cryptographically verify Ed25519 compact JWS lease
        final lease = _leaseVerifier.verify(
          jwsToken: jwsToken,
          expectedSubject: _hashToken(purchaseToken),
          expectedIssuer: effectiveIssuerUrl,
        );

        if (lease == null) {
          if (kDebugMode) {
            print('REMOTE VERIFIER [Error]: JWS lease verification failed cryptographically.');
          }
          return null;
        }

        // Update entitlement manager with valid verified 7-day lease
        if (_entitlementManager != null) {
          await _entitlementManager!.updateLease(lease);
        }

        final verifiedEntitlement = PremiumEntitlement.active(
          productId: purchaseDetails.productID,
          storeSource: storeSource,
          verifiedAt: lease.issuedAt,
          transactionReference: purchaseDetails.purchaseID,
          originalPurchaseDate: purchaseDetails.transactionDate,
          rawMetadata: {
            'status': 'ACTIVE',
            'verificationSource': 'remote_cloudflare_worker',
            'leaseKid': lease.kid,
            'leaseExpiresAt': lease.expiresAt.toIso8601String(),
          },
        );

        return verifiedEntitlement;
      }

      // Non-200, Non-403 responses (e.g. 400 Bad Request, 500 Server Error)
      if (kDebugMode) {
        print('REMOTE VERIFIER [Warning]: Server returned HTTP ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      // Network failure, timeout, or unreachable server
      // Rule: Do NOT revoke active entitlement on network error.
      if (kDebugMode) {
        print('REMOTE VERIFIER [Network Error]: $e');
      }
      return null;
    }
  }

  /// Extracts the Google Play purchase token from [PurchaseDetails].
  ///
  /// In Google Play billing via Flutter in_app_purchase, serverVerificationData
  /// contains the raw purchase token string or purchase JSON.
  String? _extractPurchaseToken(PurchaseDetails details) {
    final serverData = details.verificationData.serverVerificationData;
    if (serverData.isNotEmpty) {
      if (serverData.startsWith('{')) {
        try {
          final Map<String, dynamic> parsed = jsonDecode(serverData);
          if (parsed.containsKey('purchaseToken')) {
            return parsed['purchaseToken'] as String;
          }
        } catch (_) {}
      }
      return serverData;
    }

    final localData = details.verificationData.localVerificationData;
    if (localData.isNotEmpty) {
      if (localData.startsWith('{')) {
        try {
          final Map<String, dynamic> parsed = jsonDecode(localData);
          if (parsed.containsKey('purchaseToken')) {
            return parsed['purchaseToken'] as String;
          }
        } catch (_) {}
      }
      return localData;
    }

    return null;
  }

  String _hashToken(String token) {
    return JwsLeaseVerifier.sha256Hex(token);
  }
}
