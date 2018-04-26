import 'package:mqtt_client/mqtt_client.dart';
import 'dart:async';
import 'package:observable/observable.dart';

Future<int> main(List<String> arguments) async {
  final MqttClient client = new MqttClient("ws://nano.nifni.net/mqtt", "paddle");

  /// A websocket URL must start with ws:// or Dart will throw an exception, consult your websocket MQTT broker
  /// for details.
  /// To use websockets add the following lines -:
  /// client.useWebSocket = true;
  /// client.port = 80;  ( or whatever your WS port is)

  /// Set logging on if needed, defaults to off
  client.logging(true);

  /// If you intend to use a keep alive value in your connect message that is not the default(60s)
  /// you must set it here
  client.keepAlivePeriod = 30;

  /// Add the unsolicited disconnection callback
  client.onDisconnected = onDisconnected;
  client.useWebSocket = true;
  //client.secure = true;
  client.port = 1884;

  /// Create a connection message to use or use the default one. The default one sets the
  /// client identifier, any supplied username/password, the default keepalive interval(60s)
  /// and clean session, an example of a specific one below.
  final MqttConnectMessage connMess = new MqttConnectMessage()
      .withClientIdentifier("paddle")
      .keepAliveFor(30) // Must agree with the keep alive set above
      .withWillTopic("sharedconfig")
      .authenticateAs("paddle", "pw");
  client.connectionMessage = connMess;

  /// Connect the client, any errors here are communicated by raising of the appropriate exception. Note
  /// in some circumstances the broker will just disconnect us, see the spec about this, we however eill
  /// never send malformed messages.
  try {
    await client.connect("paddle", "pw");
  } catch (e) {
    /// Error handling.....
    print(e);
    client.disconnect();
  }

  /// Check we are connected
  if (client.connectionState == ConnectionState.connected) {
    print("EXAMPLE::Mosquitto client connected");
  } else {
    print(
        "EXAMPLE::ERROR Mosquitto client connection failed - disconnecting, state is ${client
            .connectionState}");
    client.disconnect();
  }

  /// Ok, lets try a subscription
  final String topic = "sharedconfig";
  final ChangeNotifier<MqttReceivedMessage> cn =
  client.listenTo(topic, MqttQos.exactlyOnce);

  /// We get a change notifier object(see the Observable class) which we then listen to to get
  /// notifications of published updates to each subscribed topic, one for each topic, these are
  /// basically standard Dart streams and can be managed as you wish.
  cn.changes.listen((List<MqttReceivedMessage> c) {
    final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
    final String pt =
    MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    /// The above may seem a little convoluted for users only interested in the
    /// payload, some users however may be interested in the received publish message,
    /// lets not constrain ourselves yet until the package has been in the wild
    /// for a while.
    /// The payload is a byte buffer, this will be specific to the topic
    print("EXAMPLE::Change notification:: payload is <$pt> for topic <$topic>");
  });

  /// Sleep to read the log.....
  await MqttUtilities.asyncSleep(5);

  /// Lets publish to a topic, use a high QOS
  // Publish a known topic
  final String pubTopic = "Dart/Mqtt_client/testtopic";
  // Use the payload builder rather than a raw buffer
  final MqttClientPayloadBuilder builder = new MqttClientPayloadBuilder();
  builder.addString("Hello");
  client.publishMessage(pubTopic, MqttQos.exactlyOnce, builder.payload);

  /// Ok, we will now sleep a while, in this gap you will see ping request/response
  /// messages being exchanged by the keep alive mechanism.
  print("EXAMPLE::Sleeping....");
  //await MqttUtilities.asyncSleep(120);

  /// Finally, unsubscribe and exit gracefully
  print("EXAMPLE::Unsubscribing");
  client.unsubscribe(topic);

  /// Wait for the unsubscribe message from the broker if you wish.
  //await MqttUtilities.asyncSleep(2);
  print("EXAMPLE::Disconnecting");
  client.disconnect();
  return 0;
}

/// The unsolicited disconnect callback
void onDisconnected() {
  print("Client unsolicited disconnection");
}
