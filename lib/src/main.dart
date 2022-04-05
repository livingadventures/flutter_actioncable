import 'package:flutter_actioncable/src/consumer.dart';

Consumer createConsumer(String url, [bool debug = true]) {
  return Consumer(url: url, debug: debug);
}
