import 'dart:io';

void main() {
  final file = File(r'E:\Android\projects\raasta_app\lib\presentation\providers\drive_provider.dart');
  var code = file.readAsStringSync();

  // 1. Add imports
  code = code.replaceFirst(
    "import 'package:flutter/foundation.dart';",
    "import 'package:flutter/widgets.dart';\nimport 'package:wakelock_plus/wakelock_plus.dart';"
  );

  // 2. Mix in WidgetsBindingObserver and add to constructor
  final constructorFrom = '''class DriveProvider extends ChangeNotifier {
  DriveProvider({
    HazardDetector? detector,
    TtsService? tts,
    GpsService? gps,
    PermissionService? permissions,
    WrongWayService? wrongWay,
    Random? random,
  }) : _detector = detector ?? SimulatedHazardDetector(),
       _tts = tts ?? TtsService(),
       _gps = gps ?? GpsService(),
       _permissions = permissions ?? PermissionService(),
       _wrongWay = wrongWay ?? WrongWayService(),
       _random = random ?? Random();''';

  final constructorTo = '''class DriveProvider extends ChangeNotifier with WidgetsBindingObserver {
  DriveProvider({
    HazardDetector? detector,
    TtsService? tts,
    GpsService? gps,
    PermissionService? permissions,
    WrongWayService? wrongWay,
    Random? random,
  }) : _detector = detector ?? SimulatedHazardDetector(),
       _tts = tts ?? TtsService(),
       _gps = gps ?? GpsService(),
       _permissions = permissions ?? PermissionService(),
       _wrongWay = wrongWay ?? WrongWayService(),
       _random = random ?? Random() {
    WidgetsBinding.instance.addObserver(this);
  }''';

  code = code.replaceFirst(constructorFrom, constructorTo);

  // 3. Add lifecycle hook and _updateWakelock
  final lifecycleHook = '''
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_status == DriveStatus.running || _status == DriveStatus.arming) {
        togglePause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_status == DriveStatus.paused) {
        togglePause();
      }
    }
  }

  void _updateWakelock() {
    if (_status == DriveStatus.running || _status == DriveStatus.arming) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }
''';

  // Inject before configure
  code = code.replaceFirst("  Future<void> configure({", lifecycleHook + "\n  Future<void> configure({");

  // 4. Update _status changes
  code = code.replaceFirst(
    '''    _status = DriveStatus.idle;
    notifyListeners();''',
    '''    _status = DriveStatus.idle;
    _updateWakelock();
    notifyListeners();'''
  );

  code = code.replaceFirst(
    '''      _status = DriveStatus.arming;
      notifyListeners();''',
    '''      _status = DriveStatus.arming;
      _updateWakelock();
      notifyListeners();'''
  );

  code = code.replaceFirst(
    '''    _status = DriveStatus.running;
    _startedAt = DateTime.now();
    _stationarySince = null;
    notifyListeners();''',
    '''    _status = DriveStatus.running;
    _startedAt = DateTime.now();
    _stationarySince = null;
    _updateWakelock();
    notifyListeners();'''
  );

  code = code.replaceFirst(
    '''    if (_status == DriveStatus.running) {
      _status = DriveStatus.paused;
      _stationarySince = null;
    } else if (_status == DriveStatus.paused) {
      _status = DriveStatus.running;
    }
    notifyListeners();''',
    '''    if (_status == DriveStatus.running) {
      _status = DriveStatus.paused;
      _stationarySince = null;
    } else if (_status == DriveStatus.paused) {
      _status = DriveStatus.running;
    }
    _updateWakelock();
    notifyListeners();'''
  );

  code = code.replaceFirst(
    '''    final wasArming = _status == DriveStatus.arming;
    _status = DriveStatus.finished;
    await _tearDownSensors();
    await _tts.stop();
    notifyListeners();''',
    '''    final wasArming = _status == DriveStatus.arming;
    _status = DriveStatus.finished;
    _updateWakelock();
    await _tearDownSensors();
    await _tts.stop();
    notifyListeners();'''
  );

  code = code.replaceFirst(
    '''    if (_status == DriveStatus.arming) {
      _status = DriveStatus.running;
      _startedAt = DateTime.now();
      _stationarySince = null;
    }''',
    '''    if (_status == DriveStatus.arming) {
      _status = DriveStatus.running;
      _startedAt = DateTime.now();
      _stationarySince = null;
      _updateWakelock();
    }'''
  );

  // 5. Cleanup observer on dispose
  code = code.replaceFirst(
    '''  @override
  void dispose() {''',
    '''  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);'''
  );

  file.writeAsStringSync(code);
  print("DriveProvider patched successfully.");
}
