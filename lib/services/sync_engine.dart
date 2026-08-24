import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sync_outbox_item.dart';
import '../models/sync_mutation_request.dart';
import '../models/sync_mutation_ack.dart';
import '../repositories/outbox_repository.dart';
import 'sync_network_client.dart';
import 'session_manager.dart';

import 'pull_sync_engine.dart';

/// Engine operational state.
enum SyncEngineState {
  idle,
  flushing,
  pausedAuthentication,
  stopped,
}

/// SyncEngine — Orchestration service for processing local outbox mutations and pulling remote changes.
class SyncEngine {
  final OutboxRepository _outboxRepo;
  final SyncNetworkClient _networkClient;
  final SessionManager _sessionManager;
  final PullSyncEngine _pullSyncEngine;

  final int initialDelaySeconds;
  final double multiplier;
  final int maximumDelaySeconds;
  final int maxAttempts;
  final DateTime Function() nowProvider;

  SyncEngineState _state = SyncEngineState.idle;
  bool _isFlushing = false;
  bool _isDisposed = false;

  SyncEngineState get state => _state;
  bool get isFlushing => _isFlushing;

  SyncEngine({
    OutboxRepository? outboxRepo,
    required SyncNetworkClient networkClient,
    SessionManager? sessionManager,
    PullSyncEngine? pullSyncEngine,
    this.initialDelaySeconds = 2,
    this.multiplier = 2.0,
    this.maximumDelaySeconds = 300,
    this.maxAttempts = 10,
    DateTime Function()? nowProvider,
  })  : _outboxRepo = outboxRepo ?? SqliteOutboxRepository(),
        _networkClient = networkClient,
        _sessionManager = sessionManager ?? SessionManager(),
        _pullSyncEngine = pullSyncEngine ??
            PullSyncEngine(
              networkClient: networkClient,
              sessionManager: sessionManager,
            ),
        nowProvider = nowProvider ?? DateTime.now;

  /// Initializes engine state on application startup.
  Future<void> initialize() async {
    _state = SyncEngineState.idle;
    _isFlushing = false;
    _isDisposed = false;
  }

  /// Calculates exponential backoff delay based on attempt count.
  Duration calculateBackoff(int attemptCount) {
    if (attemptCount <= 0) return Duration(seconds: initialDelaySeconds);
    final double rawDelay =
        (initialDelaySeconds * pow(multiplier, attemptCount)).toDouble();
    final int clampedDelay = min(rawDelay.round(), maximumDelaySeconds);
    return Duration(seconds: clampedDelay);
  }

  /// Triggers outbox queue processing for active session user.
  Future<void> flush() async {
    if (_isDisposed || _isFlushing || _state == SyncEngineState.stopped) {
      return;
    }

    final activeUserId = _sessionManager.activeUserId;
    if (activeUserId == null || activeUserId.isEmpty) {
      debugPrint('SyncEngine flush skipped: No active session.');
      return;
    }

    _isFlushing = true;
    _state = SyncEngineState.flushing;

    try {
      final items = await _outboxRepo.getPendingOutboxItems(activeUserId);
      if (items.isNotEmpty) {
        for (final item in items) {
          // Session isolation guard before every mutation
          if (_sessionManager.activeUserId != activeUserId ||
              _state == SyncEngineState.stopped) {
            debugPrint(
                'SyncEngine flush aborted: Session changed or engine stopped.');
            break;
          }

          // Retry eligibility check based on nextAttemptAt
          final now = nowProvider();
          if (item.nextAttemptAt != null && item.nextAttemptAt!.isAfter(now)) {
            debugPrint(
                'SyncEngine skipping item ${item.id}: Backoff timer active until ${item.nextAttemptAt}');
            continue;
          }

          final success = await _processItem(item, activeUserId);
          if (!success) {
            // If paused for authentication or transient error, exit loop
            if (_state == SyncEngineState.pausedAuthentication) {
              break;
            }
          }
        }
      }

      // Execute PULL phase if authentication is valid and session matches
      if (_state != SyncEngineState.pausedAuthentication &&
          _sessionManager.activeUserId == activeUserId &&
          !_isDisposed &&
          _state != SyncEngineState.stopped) {
        try {
          await _pullSyncEngine.pull(activeUserId: activeUserId);
        } catch (e) {
          debugPrint('SyncEngine: Error during pull phase: $e');
        }
      }
    } catch (e, stack) {
      debugPrint('SyncEngine flush error: $e\n$stack');
    } finally {
      _isFlushing = false;
      if (_state == SyncEngineState.flushing) {
        _state = SyncEngineState.idle;
      }
    }
  }

  Future<bool> _processItem(SyncOutboxItem item, String activeUserId) async {
    final token = await _sessionManager.getIdToken();

    Map<String, dynamic> payloadMap;
    try {
      payloadMap = item.payloadMap;
    } catch (_) {
      await _outboxRepo.updateOutboxItemRetryStatus(
        id: item.id,
        attemptCount: item.attemptCount + 1,
        status: 'failed',
        lastAttemptAt: nowProvider(),
        lastError: 'Malformed payload JSON',
      );
      return false;
    }

    final request = SyncMutationRequest(
      operationId: item.operationId,
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      localVersion: item.localVersion,
      payload: payloadMap,
      createdAt: item.createdAt,
    );

    try {
      final pushResult = await _networkClient.pushMutations(
        userId: activeUserId,
        authToken: token ?? '',
        mutations: [request],
      );

      if (pushResult.acknowledgements.isEmpty) {
        await _handleError(
          item,
          const SyncNetworkException(
            type: SyncNetworkErrorType.malformedResponse,
            message: 'Server returned empty acknowledgement list',
          ),
        );
        return false;
      }

      final ack = pushResult.acknowledgements.first;

      // Validate ACK operationId
      if (ack.operationId != item.operationId) {
        await _handleError(
          item,
          SyncNetworkException(
            type: SyncNetworkErrorType.malformedResponse,
            message:
                'ACK operationId mismatch: expected ${item.operationId}, got ${ack.operationId}',
          ),
        );
        return false;
      }

      // Process valid ACK / STALE ACK
      if (ack.status == SyncAckStatus.acknowledged ||
          ack.status == SyncAckStatus.stale) {
        await _outboxRepo.acknowledgeOutboxItem(
          outboxId: item.id,
          entityType: item.entityType,
          entityId: item.entityId,
          localVersion: item.localVersion,
        );
        return true;
      }

      return false;
    } on SyncNetworkException catch (ex) {
      await _handleError(item, ex);
      return false;
    } catch (ex) {
      await _handleError(
        item,
        SyncNetworkException(
          type: SyncNetworkErrorType.transientFailure,
          message: ex.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> _handleError(
      SyncOutboxItem item, SyncNetworkException ex) async {
    final now = nowProvider();

    switch (ex.type) {
      case SyncNetworkErrorType.authenticationFailure:
        _state = SyncEngineState.pausedAuthentication;
        debugPrint('SyncEngine paused due to authentication failure.');
        break;

      case SyncNetworkErrorType.transientFailure:
        final newAttempt = item.attemptCount + 1;
        if (newAttempt >= maxAttempts) {
          await _outboxRepo.updateOutboxItemRetryStatus(
            id: item.id,
            attemptCount: newAttempt,
            status: 'failed',
            lastAttemptAt: now,
            lastError:
                'Max attempts ($maxAttempts) reached. Last error: ${ex.message}',
          );
        } else {
          final backoffDelay = calculateBackoff(newAttempt);
          final nextAttemptAt = now.add(backoffDelay);
          await _outboxRepo.updateOutboxItemRetryStatus(
            id: item.id,
            attemptCount: newAttempt,
            status: 'pending',
            lastAttemptAt: now,
            nextAttemptAt: nextAttemptAt,
            lastError: ex.message,
          );
        }
        break;

      case SyncNetworkErrorType.permanentRejection:
      case SyncNetworkErrorType.malformedResponse:
        await _outboxRepo.updateOutboxItemRetryStatus(
          id: item.id,
          attemptCount: item.attemptCount + 1,
          status: 'failed',
          lastAttemptAt: now,
          lastError: ex.message,
        );
        break;
    }
  }

  /// Resumes engine from paused authentication state.
  void resumeFromAuthFailure() {
    if (_state == SyncEngineState.pausedAuthentication) {
      _state = SyncEngineState.idle;
    }
  }

  /// Stops sync operations immediately.
  void stop() {
    _state = SyncEngineState.stopped;
    _isFlushing = false;
  }

  /// Releases resources.
  void dispose() {
    _isDisposed = true;
    _state = SyncEngineState.stopped;
    _isFlushing = false;
  }
}
