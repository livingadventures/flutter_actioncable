import 'dart:developer' as logger;
import 'dart:math';
import 'package:async/async.dart';
import 'package:flutter_actioncable/src/connection.dart';

class ConnectionMonitor {
  Connection connection;
  int reconnectAttempts = 0;
  int? pingedAt;
  int? startedAt;
  int? stoppedAt;
  int? disconnectedAt;
  CancelableOperation? pollTimer;

  int staleThreshold = 6;
  double reconnectionBackoffRate = 0.15;

  ConnectionMonitor(this.connection);

  int now() => DateTime.now().millisecondsSinceEpoch;
  int secondsSince(int time) => (now() - time) ~/ 1000;

  int? get refreshedAt => pingedAt ?? startedAt;
  bool get connectionIsStale => secondsSince(refreshedAt!) > staleThreshold;
  bool get disconnectedRecenly =>
      disconnectedAt != null && secondsSince(disconnectedAt!) < staleThreshold;

  bool get isRunning => startedAt != null && stoppedAt == null;

  double get pollInterval {
    double backoff = pow(
      1.0 + reconnectionBackoffRate,
      min(
        reconnectAttempts,
        10,
      ),
    ) as double;
    double jitterMax = reconnectAttempts == 0 ? 1.0 : reconnectionBackoffRate;
    double jitter = Random().nextDouble() * jitterMax;
    return staleThreshold * 1000.0 * backoff * (1.0 + jitter);
  }

  start() {
    if (!isRunning) {
      startedAt = now();
      stoppedAt = null;
      startPolling();
    }
  }

  stop() {
    if (isRunning) {
      stoppedAt = now();
      stopPolling();
    }
  }

  void recordPing() {
    pingedAt = now();
  }

  void recordConnect() {
    reconnectAttempts = 0;
    recordPing();
    disconnectedAt = null;
  }

  void recordDisconnect() {
    disconnectedAt = now();
  }

  void startPolling() {
    stopPolling();
    poll();
  }

  void stopPolling() {
    pollTimer?.cancel();
  }

  void poll() {
    pollTimer = CancelableOperation.fromFuture(
      Future.delayed(
        Duration(milliseconds: pollInterval.toInt()),
        () {
          reconnectIfStale();
          poll();
        },
      ),
    );
  }

  void reconnectIfStale() {
    if (connectionIsStale) {
      reconnectAttempts++;
      if (disconnectedRecenly) {
        logger.log(
            "ConnectionMonitor skipping reopening recent disconnect. time disconnected = ${secondsSince(disconnectedAt!)} s");
      } else {
        logger.log('ConnectionMonitor reopening');
        connection.reopen();
      }
    }
  }
}
