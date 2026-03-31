import 'package:flutter/material.dart';
import 'package:awasmui/rust/generated/api.dart' as api;
import 'package:awasmui/rust/generated/frb_generated.dart' as frb;
import 'dart:async';

/// Any page can call `await HandleStore.instance.handle` to get the same initialized handle.
class HandleStore {
  HandleStore._();
  static final HandleStore instance = HandleStore._();

  api.Handle? _handle;
  Future<api.Handle>? _handleFuture;
  Future<void>? _initFuture;

  Future<void> _ensureInitialized() {
    if (_initFuture != null) return _initFuture!;
    // Call the generated init on the dart side. Await it once.
    _initFuture = frb.RustLib.init().catchError((e) {
      // Reset on error so callers can retry
      _initFuture = null;
      throw e;
    });
    return _initFuture!;
  }

  Future<api.Handle> get handle {
    if (_handle != null) return Future.value(_handle!);
    if (_handleFuture != null) return _handleFuture!;

    // Ensure FRB runtime initialized, then create the handle.
    _handleFuture = _ensureInitialized()
        .then((_) => api.newHandle())
        .then((h) {
          _handle = h;
          _handleFuture = null;
          return h;
        })
        .catchError((e) {
          _handleFuture = null;
          throw e;
        });
    return _handleFuture!;
  }

  /// Optional: allow manual reset for tests/dev
  void reset() {
    _handle = null;
    _handleFuture = null;
    _initFuture = null;
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<api.Handle> _handleFuture;

  @override
  void initState() {
    super.initState();
    // Start initializing the handle immediately on app start.
    _handleFuture = HandleStore.instance.handle;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'aWASM Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // Wait for the handle once at top-level so home page / routes can assume initialization
      home: FutureBuilder<api.Handle>(
        future: _handleFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Simple splash while handle is created
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Failed to init handle: ${snapshot.error}')),
            );
          } else {
            final handle = snapshot.data!;
            // Pass the ready handle into the home page (you can also rely on HandleStore from other pages)
            return MyHomePage(title: 'aWASM Demo', handle: handle);
          }
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.handle});
  final String title;
  final api.Handle handle;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _result = 'None';
  bool _loading = false;

  // Example: call an async method on the handle and update state.
  // Replace `doSomethingAsync` with a real method from your Handle.
  Future<void> _callHandleExample() async {
    setState(() => _loading = true);
    try {
      // Example placeholder - replace with your actual API call:
      // final res = await widget.handle.someAsyncMethod('Naruto');
      // setState(() => _result = res.toString());
      await Future.delayed(const Duration(milliseconds: 200)); // placeholder
      setState(() => _result = 'example result');
    } catch (e) {
      setState(() => _result = 'error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Result for \'Naruto\''),
            if (_loading) const CircularProgressIndicator(),
            Text(_result, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _callHandleExample,
              child: const Text('Call Handle'),
            ),
            const SizedBox(height: 8),
            // ElevatedButton(
            //   onPressed: _openOtherPage,
            //   child: const Text('Open other page'),
            // ),
          ],
        ),
      ),
    );
  }
}
