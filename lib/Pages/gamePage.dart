import 'dart:async';
import 'dart:math';

import 'package:dinogrow/Models/connect_data.dart';
import 'package:dinogrow/Models/display_data,dart';
import 'package:dinogrow/Services/get_connect_data.dart';
import 'package:dinogrow/Services/get_display_data.dart';
import 'package:dinogrow/Services/save_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:solana/solana.dart';

class RandomNumberGame extends StatefulWidget {
  const RandomNumberGame({super.key});

  @override
  State<RandomNumberGame> createState() => _RandomNumberGameState();
}

class _RandomNumberGameState extends State<RandomNumberGame> {
  int randomNumber = 0;
  bool isFrozen = false;
  ConnectData connectData = ConnectData();
  DisplayData displayData = DisplayData();
  @override
  void initState() {
    super.initState();

    startRandomNumberGenerator();
  }

  void startRandomNumberGenerator() {
    Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (!isFrozen) {
        setState(() {
          randomNumber = Random().nextInt(1000);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick a number!'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          GoRouter.of(context).go("/home");
        },
        backgroundColor: Colors.white.withOpacity(0.3),
        child: const Icon(
          Icons.arrow_back,
        ),
      ),
      body: GestureDetector(
        onTap: () {
          if (!isFrozen) {
            freezeNumber();
          }
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Random Number: $randomNumber',
                style: TextStyle(fontSize: 20),
              ),
              if (isFrozen)
                ElevatedButton(
                  onPressed: () async {
                    connectData = await getconnectdata();
                    displayData = await getDisplayData(connectData);
                    final result =
                        await saveScore(connectData, BigInt.from(randomNumber));
                    display_result(result);
                  },
                  child: Text('Send Score'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void display_result(String result) {
    String truncResult = truncateString(result);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.transparent,
                child: displayData.chainLogo,
              ),
              Text("Transaction Completed with result"),
            ],
          ),
          content: Row(
            children: [
              Text(" $truncResult"),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: result));
                },
              ),
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text("Close"),
              onPressed: () {
                GoRouter.of(context).go("/home");
              },
            ),
          ],
        );
      },
    );
  }

  void freezeNumber() {
    setState(() {
      isFrozen = true;
    });
  }
}
