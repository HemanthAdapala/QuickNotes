import '../models/sync_mutation_request.dart';
import '../models/sync_mutation_ack.dart';
import '../models/sync_pull_request.dart';
import '../models/sync_pull_response.dart';

/// Categories of provider-neutral synchronization network errors.
enum SyncNetworkErrorType {
  authenticationFailure,
  transientFailure,
  permanentRejection,
  malformedResponse,
}

/// SyncNetworkException — Typed exception thrown by concrete network adapters.
class SyncNetworkException implements Exception {
  final SyncNetworkErrorType type;
  final String message;
  final Object? cause;

  const SyncNetworkException({
    required this.type,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'SyncNetworkException($type): $message';
}

/// SyncPushResult — Envelope returned upon pushing a batch of mutations to cloud server.
class SyncPushResult {
  final List<SyncMutationAck> acknowledgements;

  const SyncPushResult({
    required this.acknowledgements,
  });

  Map<String, dynamic> toMap() {
    return {
      'acknowledgements': acknowledgements.map((a) => a.toMap()).toList(),
    };
  }

  factory SyncPushResult.fromMap(Map<String, dynamic> map) {
    final rawAcks = map['acknowledgements'] as List? ?? [];
    return SyncPushResult(
      acknowledgements: rawAcks
          .map((a) => SyncMutationAck.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
    );
  }
}

/// SyncNetworkClient — Central abstract interface defining provider-neutral
/// transport contracts for pushing mutations and pulling changes.
abstract class SyncNetworkClient {
  /// Pushes a batch of outbox mutations to remote server under an authenticated session context.
  Future<SyncPushResult> pushMutations({
    required String userId,
    required String authToken,
    required List<SyncMutationRequest> mutations,
  });

  /// Pulls delta changes from remote server given a checkpoint cursor.
  Future<SyncPullResponse> pullChanges({
    required String userId,
    required String authToken,
    required SyncPullRequest request,
  });
}
