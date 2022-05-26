import 'package:flutter_actioncable/src/consumer.dart';
import 'package:flutter_actioncable/src/subscription.dart';
import 'package:flutter_actioncable/src/subscription_guarantor.dart';

class Subscriptions {
  Consumer consumer;
  late SubscriptionGuarantor subscriptionGuarantor;
  late List<Subscription> subscriptions;

  Subscriptions(this.consumer) {
    subscriptions = [];
    subscriptionGuarantor = SubscriptionGuarantor(this);
  }

  Future<Subscription> add(Subscription subscription) async {
    subscriptions.add(subscription);
    await consumer.ensureActiveConnection();
    notify(subscription, 'initialized');
    subscribe(subscription);

    return subscription;
  }

  Future<Subscription> create({
    required String channelName,
    required Function(dynamic) onData,
    String? room,
  }) async {
    Subscription subscription = Subscription(
      consumer,
      {
        'channel': channelName,
        if (room != null) 'room': room,
      },
      onData: onData,
    );

    return add(subscription);
  }

  remove(Subscription subscription) {
    forget(subscription);
    if (findAll(subscription.identifier).isEmpty) {
      sendCommand(subscription, 'unsubscribe');
    }
  }

  reject(String identifier) {
    for (Subscription subscription in findAll(identifier)) {
      forget(subscription);
      notify(subscription, 'rejected');
    }
  }

  Subscription forget(Subscription subscription) {
    subscriptionGuarantor.forget(subscription);
    subscriptions.remove(subscription);

    return subscription;
  }

  List<Subscription> findAll(String identifier) {
    return subscriptions
        .where((Subscription subscription) =>
            subscription.identifier == identifier)
        .toList();
  }

  sendCommand(Subscription subscription, String command) {
    return consumer.send(
      {
        'command': command,
        'identifier': subscription.identifier,
      },
    );
  }

  notifyAll(String functionName, [dynamic data]) {
    return subscriptions.map(
      (Subscription subscription) => notify(
        subscription,
        functionName,
        data,
      ),
    );
  }

  notifyByIdentifier(
    String identifier,
    String functionName, [
    dynamic data,
  ]) {
    for (Subscription subscription in findAll(identifier)) {
      notify(subscription, functionName, data);
    }
  }

  void notify(Subscription subscription, String functionName, [dynamic data]) {
    switch (functionName) {
      case 'unsubscribe':
        subscription.unsubscribe();
        break;
      case 'initialized':
        if (subscription.onCreated != null) {
          subscription.onCreated!();
        }
        break;
      case 'received':
        if (subscription.onData != null) {
          subscription.onData!(data);
        }
        break;
    }
  }

  subscribe(Subscription subscription) {
    if (sendCommand(subscription, 'subscribe')) {
      subscriptionGuarantor.guarantee(subscription);
    }
  }

  reload() {
    return subscriptions
        .map((Subscription subscription) => subscribe(subscription));
  }

  confirmSubscription(String identifier) {
    findAll(identifier).forEach((subscription) {
      subscriptionGuarantor.forget(subscription);
    });
  }
}
