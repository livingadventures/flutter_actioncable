import 'package:async/async.dart';
import 'package:flutter_actioncable/src/subscription.dart';
import 'package:flutter_actioncable/src/subscriptions.dart';

class SubscriptionGuarantor {
  late List<Subscription> pendingSubscriptions;
  CancelableOperation? retryFuture;
  Subscriptions subscriptions;

  SubscriptionGuarantor(this.subscriptions) {
    pendingSubscriptions = [];
  }

  guarantee(Subscription subscription) {
    if (!pendingSubscriptions.contains(subscription)) {
      pendingSubscriptions.add(subscription);
    }
    startGuaranteeing();
  }

  forget(Subscription subscription) {
    pendingSubscriptions.remove(subscription);
  }

  startGuaranteeing() {
    stopGuaranteeing();
    retrySubscribing();
  }

  stopGuaranteeing() {
    retryFuture?.cancel();
  }

  retrySubscribing() {
    retryFuture = CancelableOperation.fromFuture(
      Future.delayed(
        const Duration(milliseconds: 500),
        () {
          for (var subscription in pendingSubscriptions) {
            subscriptions.subscribe(subscription);
          }
        },
      ),
    );
  }
}
