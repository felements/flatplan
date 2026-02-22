import 'package:freezed_annotation/freezed_annotation.dart';
import 'category.dart';

part 'period.freezed.dart';
part 'period.g.dart';

@freezed
sealed class Period with _$Period {
  const factory Period({
    required String id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required String baseCurrency,
    required DateTime lastModified,
    @Default([]) List<Category> categories,
  }) = _Period;

  factory Period.fromJson(Map<String, dynamic> json) => _$PeriodFromJson(json);
}
