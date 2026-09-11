import 'package:flatplan/src/logic/period_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('is zero for two moments on the same calendar day', () {
    expect(
      wholeDaysBetween(DateTime(2026, 3, 5, 9), DateTime(2026, 3, 5, 23, 59)),
      0,
    );
  });

  test('ignores the time of day across a normal span', () {
    // 09:00 on the 5th through to the 25th is 20 calendar days.
    expect(wholeDaysBetween(DateTime(2026, 3, 5, 9), DateTime(2026, 3, 25)), 20);

    // The raw difference truncates the part-day away and reports 19. That
    // is the bug this helper exists to keep out of the day counts.
    expect(
      DateTime(2026, 3, 25).difference(DateTime(2026, 3, 5, 9)).inDays,
      19,
    );
  });

  test('counts calendar days across a spring-forward', () {
    // Daylight saving starts 2026-03-08 in the US and 2026-03-29 in the
    // EU. A local-time difference spanning either is an hour short, so
    // truncation loses a second whole day on top of the time of day.
    // Both windows below straddle one of the transitions; the answer is
    // three calendar days in every zone, with or without a DST rule.
    //
    // Measured naive `.difference(...).inDays` for the first pair:
    // 2 under TZ=America/New_York, 3 under Europe/Berlin and UTC. For the
    // second pair: 2 under Europe/Berlin, 3 under the other two. This file
    // is expected to pass under all of them.
    expect(wholeDaysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 10)), 3);
    expect(wholeDaysBetween(DateTime(2026, 3, 28), DateTime(2026, 3, 31)), 3);

    // Same spans with barely an hour of slack at each end — the case that
    // flips the naive arithmetic over a transition.
    expect(
      wholeDaysBetween(
        DateTime(2026, 3, 7, 23, 30),
        DateTime(2026, 3, 10, 0, 30),
      ),
      3,
    );
    expect(
      wholeDaysBetween(
        DateTime(2026, 3, 28, 23, 30),
        DateTime(2026, 3, 31, 0, 30),
      ),
      3,
    );
  });

  test('goes negative once the end date has passed', () {
    expect(
      wholeDaysBetween(DateTime(2026, 3, 25, 18), DateTime(2026, 3, 24)),
      -1,
    );
  });
}
