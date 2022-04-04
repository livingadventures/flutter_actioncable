import 'dart:convert';

import 'package:flutter_actioncable/src/consumer.dart';

class Subscription {
  final Consumer consumer;
  late final String identifier;
  late final Function(dynamic)? onData;
  late final Function()? onCreated;
  Subscription(this.consumer, Map<String, dynamic> params,
      {this.onData, this.onCreated}) {
    identifier = jsonEncode(params);
  }

  dynamic perform(String action, Map<String, dynamic> data) {
    data['action'] = action;
    return send(data);
  }

  send(Map<String, dynamic> data) {
    return consumer.send(
      {
        'command': 'message',
        'identifier': identifier,
        'data': jsonEncode(data),
      },
    );
  }

  unsubscribe() {
    consumer.subscriptions.remove(this);
  }
}
