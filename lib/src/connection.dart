import 'dart:async';
import 'dart:convert';
import 'dart:developer' as logger;
import 'dart:io';
import 'package:flutter_actioncable/src/connection_monitor.dart';
import 'package:flutter_actioncable/src/consumer.dart';
import 'package:web_socket_channel/io.dart';

class Connection {
  Consumer consumer;
  int reopenDelay = 500;
  late bool disconnected;
  late WebSocket socket;
  late IOWebSocketChannel webSocketChannel;
  late ConnectionMonitor connectionMonitor;
  Connection(this.consumer) {
    disconnected = true;
    connectionMonitor = ConnectionMonitor(this);
  }

  bool send(Map<String, dynamic> data) {
    if (isOpen) {
      if (consumer.debug) {
        logger.log('Sending data');
        logger.log(jsonEncode(data));
      }
      webSocketChannel.sink.add(jsonEncode(data));
      return true;
    } else {
      return false;
    }
  }

  Future<void> open() async {
    socket = await WebSocket.connect(
      consumer.url,
      headers: {
        'Origin': 'com.example.flutter_actioncable',
      },
    );
    if (consumer.debug) {
      logger
          .log("WebSocket onopen event, using '${getProtocol()}' subprotocol");
    }
    disconnected = false;
    webSocketChannel = IOWebSocketChannel(socket);
    installEventHandlers();
    connectionMonitor.start();
  }

  String? getProtocol() {
    return socket.protocol;
  }

  bool get isOpen => getState() == 'open';
  bool get isActive => ['open', 'connecting'].contains(getState());

  String getState() {
    switch (socket.readyState) {
      case 0:
        return 'connecting';
      case 1:
        return 'open';
      case 2:
        return 'closing';
      case 3:
        return 'closed';
      default:
        throw Exception('Invalid websocket ready state');
    }
  }

  void installEventHandlers() async {
    webSocketChannel.stream.listen(
      (dynamic message) {
        Map<String, dynamic> data = jsonDecode(message);
        switch (data['type'] as String?) {
          case 'welcome':
            if (consumer.debug) {
              logger.log('Welcome received');
            }
            consumer.subscriptions.reload();
            break;
          case 'disconnect':
            if (consumer.debug) {
              logger.log('Disconnecting. Reason: ${data['reason']}');
            }
            close(allowReconnect: data['reconnect'] as bool);
            break;
          case 'ping':
            connectionMonitor.recordPing();
            break;
          case 'confirm_subscription':
            if (consumer.debug) {
              logger.log('Subscription confirmed');
              logger.log(jsonEncode(data));
            }
            consumer.subscriptions.confirmSubscription(data['identifier']);
            consumer.subscriptions.notifyByIdentifier(
              data['identifier'],
              'connected',
            );
            break;
          case 'reject_subscription':
            if (consumer.debug) {
              logger.log('Subscription rejected');
              logger.log(jsonEncode(data));
            }
            consumer.subscriptions.reject(data['identifier']);
            break;
          default:
            if (consumer.debug) {
              logger.log('Message received');
              logger.log(jsonEncode(data['message']));
            }
            consumer.subscriptions.notifyByIdentifier(
              data['identifier'],
              'received',
              data['message'],
            );
            break;
        }
      },
      onDone: () {
        if (consumer.debug) {
          logger.log('WebSocket onclose event');
        }
        if (disconnected) {
          return;
        }

        disconnected = true;
        connectionMonitor.recordDisconnect();
        consumer.subscriptions.notifyAll('disconnected');
      },
      onError: (_, __) {
        if (consumer.debug) {
          logger.log('WebSocket onerror event');
          logger.log(_.toString());
        }
      },
      cancelOnError: false,
    );
  }

  void close({bool allowReconnect = true}) {
    if (allowReconnect == false) {
      connectionMonitor.stop();
    }
    if (isOpen) {
      webSocketChannel.sink.close();
    }
  }

  void reopen() async {
    if (consumer.debug) {
      logger.log('Reopening WebSocket, current state is ${getState()}');
    }
    if (isActive) {
      try {
        close();
      } catch (_) {
        if (consumer.debug) {
          logger.log('Failed to reopen WebSocket');
          logger.log(_.toString());
        }
      } finally {
        if (consumer.debug) {
          logger.log('Reopening WebSocket in ${reopenDelay}ms');
        }
        await Future.delayed(Duration(milliseconds: reopenDelay), () {
          open();
        });
      }
    } else {
      open();
    }
  }
}
