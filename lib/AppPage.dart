import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class AppPage extends StatefulWidget {
  final BluetoothDevice server;

  const AppPage({required this.server});

  @override
  _AppPage createState() => new _AppPage();
}

class _AppPage extends State<AppPage> {
  late BluetoothConnection connection;
  bool isConnecting = true;
  bool get isConnected => connection != null && connection.isConnected;
  bool isDisconnecting = false;

  String direction = "stopped";
  double battery = 0.0;
  double temperature = 0.0;
  double obstacleDistance = 0.0;

  String _messageBuffer = '';

  @override
  void initState() {
    super.initState();

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection.input?.listen(_onDataReceived).onDone(() {
        if (isDisconnecting) {
          print('Disconnecting locally!');
        } else {
          print('Disconnected remotely!');
        }
        if (this.mounted) {
          setState(() {});
        }
      });

      _sendMessage("status");
    }).catchError((error) {
      print('Cannot connect, exception occurred');
      print(error);
    });
  }

  @override
  void dispose() {
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isConnected
            ? "PiCar Control (Connected)"
            : "PiCar Control (Disconnected)"),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
      body: SafeArea(
        child: isConnected
            ? Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sensor Data",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        // Battery Card
                        _buildSensorCard(
                          Icons.battery_charging_full,
                          "Battery",
                          "$battery V",
                          Colors.blue.shade100,
                          Colors.blue,
                        ),
                        SizedBox(height: 10),
                        // Temperature Card
                        _buildSensorCard(
                          Icons.thermostat,
                          "Temperature",
                          "$temperature °C",
                          Colors.orange.shade100,
                          Colors.orange,
                        ),
                        SizedBox(height: 10),
                        // Distance Card
                        _buildSensorCard(
                          Icons.compare_arrows,
                          "Obstacle Distance",
                          "$obstacleDistance cm",
                          Colors.green.shade100,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),

                  Expanded(child: SizedBox()),

                  // Control buttons
                  Text(
                    "Controls",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),

                  // Forward button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(Icons.arrow_upward, "Forward",
                          Colors.blue, () => _sendMessage("forward")),
                    ],
                  ),

                  // Left, Stop, Right buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(Icons.arrow_back, "Left",
                          Colors.amber, () => _sendMessage("left")),
                      SizedBox(width: 16),
                      _buildControlButton(Icons.stop, "Stop", Colors.red,
                          () => _sendMessage("stop")),
                      SizedBox(width: 16),
                      _buildControlButton(Icons.arrow_forward, "Right",
                          Colors.amber, () => _sendMessage("right")),
                    ],
                  ),

                  // Backward button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(Icons.arrow_downward, "Backward",
                          Colors.blue, () => _sendMessage("backward")),
                    ],
                  ),

                  SizedBox(height: 20),
                ],
              )
            : Center(
                child: isConnecting
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Connecting to PiCar..."),
                        ],
                      )
                    : Text(
                        "Disconnected. Please restart the app to reconnect."),
              ),
      ),
    );
  }

  Widget _buildSensorCard(IconData icon, String title, String value,
      Color bgColor, Color iconColor) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 36),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildControlButton(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        children: [
          Icon(icon, size: 30),
          SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data
    int backspacesCounter = 0;
    data.forEach((byte) {
      if (byte == 8 || byte == 127) {
        backspacesCounter++;
      }
    });
    Uint8List buffer = Uint8List(data.length - backspacesCounter);
    int bufferIndex = buffer.length;

    // Apply backspace control character
    backspacesCounter = 0;
    for (int i = data.length - 1; i >= 0; i--) {
      if (data[i] == 8 || data[i] == 127) {
        backspacesCounter++;
      } else {
        if (backspacesCounter > 0) {
          backspacesCounter--;
        } else {
          buffer[--bufferIndex] = data[i];
        }
      }
    }

    String dataString = String.fromCharCodes(buffer);

    _messageBuffer += dataString;

    try {
      Map<String, dynamic> carState = jsonDecode(_messageBuffer);

      setState(() {
        direction = carState['direction'] ?? direction;
        battery = (carState['battery'] ?? 0).toDouble();
        temperature = (carState['temperature'] ?? 0).toDouble();
        obstacleDistance = (carState['obstacle_distance'] ?? 0).toDouble();
      });

      _messageBuffer = '';
    } catch (e) {
      print("Incomplete JSON, waiting for more data...");
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();

    if (text.length > 0) {
      try {
        connection.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection.output.allSent;

        Future.delayed(Duration(milliseconds: 500), () {
          if (isConnected) {
            _sendMessage("status");
          }
        });
      } catch (e) {
        print("Error sending message: $e");
        setState(() {});
      }
    }
  }
}
