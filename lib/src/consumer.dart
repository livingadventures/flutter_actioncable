import 'package:flutter_actioncable/src/connection.dart';
import 'package:flutter_actioncable/src/subscriptions.dart';

class Consumer {
  final String url;
  late Connection _connection;
  late Subscriptions subscriptions;
  Consumer(this.url) {
    _connection = Connection(this);
    subscriptions = Subscriptions(this);
  }

  bool send(Map<String, dynamic> data) {
    return _connection.send(data);
  }

  Future<void> connect() async {
    await _connection.open();
  }

  void disconnect() {
    _connection.close(allowReconnect: false);
  }

  Future<void> ensureActiveConnection() async {
    if (!_connection.isActive) {
      await _connection.open();
    }
  }
}
