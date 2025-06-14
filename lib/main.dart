import 'package:flutter/material.dart';
import 'board.dart';

void main() => runApp(const MinesweeperApp());

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minesweeper',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: Text('Minesweeper')),
        body: Center(child: GameBoard()),
      ),
    );
  }
}
