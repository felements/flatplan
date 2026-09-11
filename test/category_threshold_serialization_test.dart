import 'package:flutter_test/flutter_test.dart';
import 'package:flatplan/src/models/models.dart';

void main() {
  test('round-trips the big-purchase threshold as snake_case', () {
    const category = Category(
      id: 'c1',
      name: 'Groceries',
      bigPurchaseThreshold: 700,
    );

    final json = category.toJson();
    expect(json['big_purchase_threshold'], 700);
    expect(Category.fromJson(json).bigPurchaseThreshold, 700);
  });

  test('defaults to null when the key is absent', () {
    final category = Category.fromJson({'id': 'c1', 'name': 'Groceries'});
    expect(category.bigPurchaseThreshold, isNull);
  });
}
