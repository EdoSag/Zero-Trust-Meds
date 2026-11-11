import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The button on a dose reminder.
const markGivenAction = 'given';

/// Labels the OS shows outside the app, in the reader's language.
class ReminderChannelTexts {
  const ReminderChannelTexts({
    required this.channelName,
    required this.channelDescription,
    required this.markGiven,
  });
  final String channelName;
  final String channelDescription;
  final String markGiven;
}

/// Hands dose reminders to the OS so they fire while Meds is closed or
/// locked. Nothing leaves the phone: no push service is involved.
abstract interface class ReminderScheduler {
  /// Starts listening for taps, including the one that launched the app.
  /// Called at launch, before the app is unlocked.
  Future<void> initialize();

  /// Makes the OS's pending reminders exactly [reminders].
  Future<void> sync(List<MedsReminder> reminders, ReminderChannelTexts texts);

  /// Drops every reminder (sign-out). A [sync] still running stops
  /// before scheduling anything more.
  Future<void> cancelAll();

  /// How many reminders the platform keeps (iOS: 64, Android: 500).
  int get limit;

  /// Puts targets taken with [takeTaps] back, to try again later.
  void putBack(List<ReminderTarget> targets);

  /// Asks for notification (and exact alarm) permission. False when off.
  Future<bool> requestPermission();

  /// Reminder taps and "Mark as given" presses, including the one that
  /// launched the app, kept until the unlocked app takes them.
  List<ReminderTarget> takeTaps();

  /// Fires when [takeTaps] has something new.
  Stream<void> get tapped;
}

/// For tests and platforms without notifications.
class NoopReminderScheduler implements ReminderScheduler {
  List<MedsReminder> scheduled = const [];
  final _tapped = StreamController<void>.broadcast();
  final pending = <ReminderTarget>[];
  int permissionAsks = 0;

  @override
  Future<void> initialize() async {}

  void tap(ReminderTarget t) {
    pending.add(t);
    _tapped.add(null);
  }

  @override
  Future<void> sync(
    List<MedsReminder> reminders,
    ReminderChannelTexts texts,
  ) async => scheduled = reminders;

  @override
  Future<void> cancelAll() async => scheduled = const [];

  @override
  int get limit => ReminderPlan.max;

  @override
  void putBack(List<ReminderTarget> targets) => pending.insertAll(0, targets);

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return true;
  }

  @override
  List<ReminderTarget> takeTaps() {
    final out = [...pending];
    pending.clear();
    return out;
  }

  @override
  Stream<void> get tapped => _tapped.stream;
}

class LocalNotificationsReminderScheduler implements ReminderScheduler {
  LocalNotificationsReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _tapped = StreamController<void>.broadcast();
  final _pending = <ReminderTarget>[];
  Future<void>? _ready;

  /// Syncs and cancels run one at a time, in order.
  Future<void> _queue = Future.value();

  /// Bumped by [cancelAll]: a sync from before it stops scheduling.
  int _generation = 0;

  Future<void> _serial(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object _) {});
    return next;
  }

  @override
  int get limit => defaultTargetPlatform == TargetPlatform.iOS
      ? ReminderPlan.maxIos
      : ReminderPlan.max;

  @override
  void putBack(List<ReminderTarget> targets) => _pending.insertAll(0, targets);

  static const _channelId = 'dose_reminders';

  static NotificationDetails _details(
    ReminderChannelTexts texts, {
    required bool offersGiven,
    required bool silent,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      texts.channelName,
      channelDescription: texts.channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      // The lock screen shows "ZT Meds", not the child or the medicine.
      visibility: NotificationVisibility.private,
      // Quiet hours.
      silent: silent,
      actions: [
        if (offersGiven)
          AndroidNotificationAction(
            markGivenAction,
            texts.markGiven,
            // Logging needs the unlocked app: the keys never sit in the
            // background. The app opens, asks to unlock, then logs it
            // (warning first if someone already did).
            showsUserInterface: true,
            cancelNotification: true,
          ),
      ],
    ),
    iOS: DarwinNotificationDetails(presentSound: !silent),
  );

  void _onResponse(NotificationResponse response) {
    final target = ReminderTarget.parse(response.payload);
    if (target == null) return;
    _pending.add(
      response.actionId == markGivenAction ? target.withMarkGiven() : target,
    );
    _tapped.add(null);
  }

  Future<void> _init() => _ready ??= () async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked when the first treatment is set up, not at
        // launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if ((launch?.didNotificationLaunchApp ?? false) && response != null) {
      _onResponse(response);
    }
  }();

  @override
  Future<void> initialize() => _init();

  @override
  List<ReminderTarget> takeTaps() {
    final out = [..._pending];
    _pending.clear();
    return out;
  }

  @override
  Stream<void> get tapped => _tapped.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? true;
      if (granted && !(await android.canScheduleExactNotifications() ?? true)) {
        await android.requestExactAlarmsPermission();
      }
      return granted;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<void> sync(List<MedsReminder> reminders, ReminderChannelTexts texts) {
    final generation = _generation;
    return _serial(() => _sync(reminders, texts, generation));
  }

  Future<void> _sync(
    List<MedsReminder> reminders,
    ReminderChannelTexts texts,
    int generation,
  ) async {
    await _init();
    // Signed out since this plan was made: nothing of it may be set.
    if (generation != _generation) return;
    final wanted = {for (final r in reminders) r.notificationId: r};
    for (final request in await _plugin.pendingNotificationRequests()) {
      if (generation != _generation) return;
      final want = wanted[request.id];
      if (want == null) {
        await _plugin.cancel(id: request.id);
      } else if (request.title == want.title &&
          request.body == want.body &&
          request.payload == want.payload) {
        wanted.remove(request.id); // Already scheduled as it should be.
      }
    }
    if (wanted.isEmpty) return;
    final exact = await _android?.canScheduleExactNotifications() ?? true;
    for (final r in wanted.values) {
      if (generation != _generation) return;
      await _plugin.zonedSchedule(
        id: r.notificationId,
        title: r.title,
        body: r.body,
        payload: r.payload,
        // An absolute instant, so the phone's own time zone doesn't matter.
        scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
        notificationDetails: _details(
          texts,
          offersGiven: r.offersGiven,
          silent: r.silent,
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() {
    // Stops a sync already running at its next step, and any queued one.
    _generation++;
    return _serial(() async {
      await _init();
      await _plugin.cancelAll();
    });
  }
}

/// Notifications on phones; nothing elsewhere (tests, desktop).
ReminderScheduler platformReminderScheduler() =>
    kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)
    ? NoopReminderScheduler()
    : LocalNotificationsReminderScheduler();

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => platformReminderScheduler(),
);
