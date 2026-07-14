import 'package:flutter/material.dart';

/// A tiny interactive island: quantity picker with a live total.
class CalculatorIsland extends StatefulWidget {
  const CalculatorIsland({required this.price, super.key});

  final int price;

  @override
  State<CalculatorIsland> createState() => _CalculatorIslandState();
}

class _CalculatorIslandState extends State<CalculatorIsland> {
  var _quantity = 1;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
          ),
          Text('$_quantity pcs — total ${_quantity * widget.price}'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _quantity++),
          ),
        ],
      ),
    ),
  );
}
