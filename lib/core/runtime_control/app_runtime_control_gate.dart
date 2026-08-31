import 'dart:async';

import 'package:flutter/material.dart';

import '../../pages/runtime_control/app_runtime_control_screen.dart';
import '../../services/app_runtime_control_service.dart';
import 'app_runtime_control_model.dart';

class AppRuntimeControlGate extends StatefulWidget {
  const AppRuntimeControlGate({
    super.key,
    required this.target,
    required this.child,
    this.pollingInterval = const Duration(minutes: 1),
  });

  final String target;
  final Widget child;
  final Duration pollingInterval;

  @override
  State<AppRuntimeControlGate> createState() => _AppRuntimeControlGateState();
}

class _AppRuntimeControlGateState extends State<AppRuntimeControlGate>
    with WidgetsBindingObserver {
  final AppRuntimeControlService _service = AppRuntimeControlService();

  AppRuntimeState _state = const AppRuntimeState.active();
  bool _cacheLoaded = false;
  bool _retrying = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
    _timer = Timer.periodic(widget.pollingInterval, (_) {
      unawaited(_refresh(showProgress: false));
    });
  }

  Future<void> _bootstrap() async {
    final cached = await _service.loadCached(widget.target);
    if (!mounted) return;

    setState(() {
      _state = cached;
      _cacheLoaded = true;
    });

    final remote = await _service.refresh(widget.target);
    if (!mounted || remote == null) return;
    setState(() => _state = remote);
  }

  Future<void> _refresh({required bool showProgress}) async {
    if (_retrying && showProgress) return;

    if (showProgress && mounted) {
      setState(() => _retrying = true);
    }

    final remote = await _service.refresh(widget.target);

    if (!mounted) return;
    setState(() {
      if (remote != null) _state = remote;
      if (showProgress) _retrying = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(showProgress: false));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_cacheLoaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(backgroundColor: Colors.white, body: SizedBox.expand()),
      );
    }

    if (!_state.blocksAccess) return widget.child;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Poppins'),
      home: AppRuntimeControlScreen(
        state: _state,
        retrying: _retrying,
        onRetry: () => _refresh(showProgress: true),
      ),
    );
  }
}
