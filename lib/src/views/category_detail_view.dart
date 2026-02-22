import 'package:flutter/material.dart';

class CategoryDetailView extends StatelessWidget {
  final String categoryId;

  const CategoryDetailView({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Category: $categoryId')),
      body: Center(
        child: Text('Category Detail Placeholder for $categoryId'),
      ),
    );
  }
}
