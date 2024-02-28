import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

// ignore: depend_on_referenced_packages, implementation_imports
import 'package:typed_data/src/typed_buffer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Carga Connect',
      home: GeoLocationPage(),
    );
  }
}

class GeoLocationPage extends StatefulWidget {
  const GeoLocationPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GeoLocationPageState createState() => _GeoLocationPageState();
}

class _GeoLocationPageState extends State<GeoLocationPage> {
  final String mqttServer = 'mqtt://your.mqtt.server';
  final String mqttTopic = 'geolocation';

  late mqtt.MqttClient client;
  bool isConnected = false;
  late Timer timer;
  late Database database;

  @override
  void initState() {
    super.initState();
    initMqtt();
    initDatabase();
    startTimer();
  }

  void initMqtt() {
    client = mqtt.MqttClient(mqttServer, '');
    client.port = 1883;
    client.keepAlivePeriod = 30;
    client.onConnected = onConnected;
    client.connect();
  }

  void onConnected() {
    // ignore: avoid_print
    print('Connected to MQTT server');
    setState(() {
      isConnected = true;
    });
  }

  void initDatabase() async {
    var directory = await getApplicationDocumentsDirectory();
    var path = '${directory.path}geolocation.db';
    database = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS locations (id INTEGER PRIMARY KEY, latitude REAL, longitude REAL)');
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(minutes: 5), (Timer t) async {
      if (isConnected) {
        sendLocation();
      } else {
        saveLocationLocally();
      }
    });
  }

  Future<void> sendLocation() async {
    Position position = await Geolocator.getCurrentPosition();
    String message = '{"latitude": ${position.latitude}, "longitude": ${position.longitude}}';
    client.publishMessage(mqttTopic, mqtt.MqttQos.exactlyOnce, message as Uint8Buffer);
  }

  Future<void> saveLocationLocally() async {
    Position position = await Geolocator.getCurrentPosition();
    await database.rawInsert(
        'INSERT INTO locations (latitude, longitude) VALUES (?, ?)',
        [position.latitude, position.longitude]);
  }

  @override
  void dispose() {
    client.disconnect();
    timer.cancel();
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carga Connect'),
      ),
      body: Center(
        child: isConnected
            ? const Text('Connected to MQTT server')
            : const Text('Disconnected from MQTT server'),
      ),
    );
  }
}
