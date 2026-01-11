import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart'; // for AppDrawer

class SOSPreview extends StatefulWidget {
  const SOSPreview({super.key});

  @override
  State<SOSPreview> createState() => _SOSPreviewState();
}

class _SOSPreviewState extends State<SOSPreview> {
  int countdown = 10;
  Timer? timer;
  bool isConfirming = false;
  double sliderValue = 0;

  void startSOS() {
    setState(() {
      isConfirming = true;
      countdown = 10;
      sliderValue = 0;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 0) {
        t.cancel();
        confirmSOS();
      } else {
        setState(() {
          countdown--;
        });
      }
    });
  }

  void cancelSOS() {
    timer?.cancel();
    setState(() {
      isConfirming = false;
      sliderValue = 0;
    });
  }

  void confirmSOS() {
    setState(() {
      isConfirming = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚨 SOS SENT SUCCESSFULLY"),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(), // ✅ SIDEBAR CONNECTED
      appBar: AppBar(
        title: const Text("SOS Alert"),
      ),
      body: Center(
        child: isConfirming ? confirmationUI() : sosButton(),
      ),
    );
  }

  Widget sosButton() {
    return ElevatedButton(
      onPressed: startSOS,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(80),
        elevation: 10,
      ),
      child: const Text(
        "SOS",
        style: TextStyle(
          fontSize: 40,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget confirmationUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text(
            "Sending SOS in",
            style: TextStyle(fontSize: 20, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),
          Text(
            "$countdown",
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 30),
          const Text("Slide right to cancel"),
          Slider(
            value: sliderValue,
            min: 0,
            max: 1,
            onChanged: (value) {
              setState(() => sliderValue = value);
              if (value > 0.9) cancelSOS();
            },
          ),
        ],
      ),
    );
  }
}
