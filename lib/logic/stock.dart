import 'package:flutter/foundation.dart';

import '../model/models.dart';

/// Where a counted medicine stands today (see [MedStock]).
@immutable
class StockStatus {
  const StockStatus({
    required this.stock,
    required this.left,
    this.perDay,
    this.runsOutOn,
    this.orderBy,
  });

  final MedStock stock;

  /// What's left after the doses given since the count; never below 0.
  final double left;

  /// How much a day goes: the running courses' planned doses, or for
  /// as-needed medicines the last two weeks' average. Null when unknown.
  final double? perDay;

  /// The first day without enough for the day's doses.
  final LocalDate? runsOutOn;

  /// When to order more: [MedStock.warnDays] before [runsOutOn].
  final LocalDate? orderBy;

  bool get isOut => left <= 0;

  /// Time to order more (or already out).
  bool lowOn(LocalDate today) =>
      isOut || (orderBy != null && !today.isBefore(orderBy!));
}

abstract final class StockMath {
  /// As-needed use is averaged over this many days.
  static const asNeededWindow = 14;

  /// [given] are the doses of the medicine logged as given (any time; only
  /// those after the count are taken off). [plannedPerDay] is what the
  /// running courses plan per day (0 when none); [today] is the person's
  /// calendar day.
  static StockStatus of({
    required MedStock stock,
    required Iterable<({DateTime at, double amount})> given,
    required double plannedPerDay,
    required DateTime nowUtc,
    required LocalDate today,
  }) {
    var used = 0.0;
    var recent = 0.0;
    final windowStart = nowUtc.subtract(const Duration(days: asNeededWindow));
    for (final g in given) {
      if (g.at.isAfter(stock.countedAt)) used += g.amount;
      if (g.at.isAfter(windowStart) && !g.at.isAfter(nowUtc)) {
        recent += g.amount;
      }
    }
    final left = stock.count - used;
    final perDay = plannedPerDay > 0
        ? plannedPerDay
        : recent > 0
        ? recent / asNeededWindow
        : null;
    LocalDate? runsOut, orderBy;
    if (perDay != null) {
      // Whole days covered, counting today as one of them.
      final days = left <= 0 ? 0 : (left / perDay).floor();
      runsOut = today.addDays(days);
      orderBy = runsOut.addDays(-stock.warnDays);
    }
    return StockStatus(
      stock: stock,
      left: left < 0 ? 0 : left,
      perDay: perDay,
      runsOutOn: runsOut,
      orderBy: orderBy,
    );
  }
}
