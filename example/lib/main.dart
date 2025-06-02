import 'package:flutter/material.dart';
import 'package:local_ref/local_ref.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Ref Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/local_usage': (context) => const LocalUsagePage(),
        '/ref_provider': (context) => const RefProviderPage(),
        '/store_provider': (context) =>
            const StoreProviderPageWrapper(), // Wrapper to provide store
      },
    );
  }
}

// --- Local Usage Example Page ---
class LocalUsagePage extends StatefulWidget {
  const LocalUsagePage({super.key});

  @override
  State<LocalUsagePage> createState() => _LocalUsagePageState();
}

class _LocalUsagePageState extends State<LocalUsagePage> {
  // 1. Create Refs directly within the State
  final _counter = ref(0);
  final _text = ref('Hello');
  late final StopHandle _watchEffectStop;

  @override
  void initState() {
    super.initState();
    // 2. Use watchEffect for side effects
    _watchEffectStop = watchEffect(() {
      debugPrint(
          'LocalUsagePage: Counter is now ${_counter.value}, Text is "${_text.value}"');
    });
  }

  @override
  void dispose() {
    // 3. Important: Dispose of refs and stop watch effects
    _counter.dispose();
    _text.dispose();
    _watchEffectStop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Local Usage')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 4. Use RefBuilder to listen to a single Ref
            RefBuilder<int>(
              ref: _counter,
              builder: (context, count) {
                return Text('Counter: $count',
                    style: Theme.of(context).textTheme.headlineMedium);
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _counter.value++,
              child: const Text('Increment Counter'),
            ),
            const SizedBox(height: 20),
            // 5. Use MultiRefBuilder to listen to multiple Refs
            MultiRefBuilder<({int counter, String text})>(
              dependencies: [_counter, _text],
              converter: (values) {
                // Safely convert List<dynamic> to a Record
                // Ensure values are not null and have expected types
                final counterVal = values.isNotEmpty && values[0] is int
                    ? values[0] as int
                    : 0;
                final textVal = values.length > 1 && values[1] is String
                    ? values[1] as String
                    : '';
                return (counter: counterVal, text: textVal);
              },
              builder: (context, record) {
                // Access values from the strongly-typed Record
                return Text('Combined: ${record.text} - ${record.counter}',
                    style: Theme.of(context).textTheme.headlineMedium);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: 'Enter text'),
              onChanged: (newText) => _text.value = newText,
              // To ensure TextField updates when _text.value changes programmatically elsewhere (if that happens)
              // and to initialize correctly, it's better to rebuild this part or use a dedicated RefBuilder for the TextField controller.
              // For simplicity here, we initialize with current value. A more robust way:
              // controller: ref(_text.value).obs((ctx, val) => TextEditingController(text:val)), // (pseudo-code, needs proper widget)
              controller: TextEditingController(text: _text.value),
            ),
            const SizedBox(height: 20),
            // Example of using .obs extension for quick RefBuilder
            _counter.obs(
                builder: (context, count) => Text('Counter (via .obs): $count',
                    textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Ref Examples'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: const Text('Local Usage Example'),
            subtitle: const Text(
                'Demonstrates creating and using Refs within a single widget.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/local_usage');
            },
          ),
          ListTile(
            title: const Text('RefProvider Example'),
            subtitle: const Text(
                'Demonstrates providing a single Ref to child widgets.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/ref_provider');
            },
          ),
          ListTile(
            title: const Text('StoreProvider Example'),
            subtitle: const Text(
                'Demonstrates providing a Store with multiple Refs.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/store_provider');
            },
          ),
        ],
      ),
    );
  }
}

// --- RefProvider Example Page ---
class RefProviderPage extends StatelessWidget {
  const RefProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Create a Ref to be provided.
    // IMPORTANT: For Refs provided via RefProvider from a StatelessWidget's build method,
    // their lifecycle isn't automatically managed by the RefProvider itself if the provider is removed.
    // It's generally safer to create such Refs in a StatefulWidget's State and dispose of them there,
    // or use a package that helps manage their lifecycle (like flutter_hooks for `useRef`).
    // For this example, we'll create it here and acknowledge the lifecycle consideration.
    final providedCounter = ref(100);
    // To ensure disposal if RefProviderPage is removed, one might use a StatefulWidget wrapper
    // or a more advanced state management pattern for `providedCounter` itself.

    return RefProvider<int>(
      ref: providedCounter,
      child: Scaffold(
        appBar: AppBar(title: const Text('RefProvider Usage')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('This counter is provided by RefProvider:'),
              // 2. Consume the Ref using RefConsumer
              RefConsumer<int>(
                builder: (context, count, _) {
                  return Text('$count',
                      style: Theme.of(context).textTheme.displayMedium);
                },
              ),
              const SizedBox(height: 20),
              // 3. Consume the Ref using context.ref()
              Builder(builder: (context) {
                final count = context.ref<int>().value;
                return Text('From context.ref(): $count',
                    style: Theme.of(context).textTheme.headlineSmall);
              }),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // 4. Access and modify the provided Ref
            // We can get it via context.ref() if we are in a descendant widget
            // Or, if we have direct access to the `providedCounter` instance (e.g. in this build method)
            providedCounter.value++;
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// --- StoreProvider Example Page ---
// Wrapper for StoreProviderPage to provide the store
class StoreProviderPageWrapper extends StatelessWidget {
  const StoreProviderPageWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Store();
    appState.register('counter', ref(0));
    appState.register('name', ref('User from Store'));
    appState.register('isDarkMode', ref(false));

    // It's good practice to dispose the store when the provider is removed.
    // If StoreProviderPageWrapper were a StatefulWidget, appState could be disposed in its dispose method.
    // Since it's a StatelessWidget here, if this widget itself can be removed from the tree and the store
    // is no longer needed, a mechanism to call appState.dispose() would be required.
    // For simplicity in this example, we're not adding complex lifecycle management here.
    // In a real app, consider where the store's lifecycle should be tied.
    return StoreProvider(
      store: appState,
      // The `StoreProvider` itself does not dispose the store.
      // The creator of the store is responsible for its disposal.
      child: const StoreProviderPage(),
    );
  }
}

class StoreProviderPage extends StatelessWidget {
  const StoreProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Access the store using context.store()
    final appState = context.store();

    // 2. Use watch for side effects on specific refs in the store
    watch(
      appState.getRef<bool>('isDarkMode')!,
      (newValue, oldValue) {
        debugPrint(
            'StoreProviderPage: Dark mode changed: $oldValue -> $newValue');
      },
      // Optional: immediate: false, // Set to true to run once immediately
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('StoreProvider Usage'),
        actions: [
          // 3. Use StoreSelector for granular rebuilds based on a derived value
          StoreSelector<bool>(
            selector: (context, store) =>
                store.getValue<bool>('isDarkMode') ?? false,
            builder: (context, isDarkMode, _) {
              return IconButton(
                icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                onPressed: () {
                  appState.setValue('isDarkMode', !isDarkMode);
                },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 4. Use StoreConsumer to listen to the entire store (rebuilds on any change)
            StoreConsumer(
              builder: (context, store, _) {
                final name = store.getValue<String>('name') ?? 'Unknown';
                return Text('Hello, $name!',
                    style: Theme.of(context).textTheme.headlineMedium);
              },
            ),
            const SizedBox(height: 10),
            // Change name example
            ElevatedButton(
              onPressed: () {
                final currentName = appState.getValue<String>('name');
                if (currentName == 'User from Store') {
                  appState.setValue('name', 'Updated User');
                } else {
                  appState.setValue('name', 'User from Store');
                }
              },
              child: const Text('Toggle Name'),
            ),
            const SizedBox(height: 20),
            // 5. Use RefBuilder with a Ref obtained from the store
            RefBuilder<int>(
              ref: appState.getRef<int>('counter')!,
              builder: (context, count) {
                return Text('Counter: $count',
                    style: Theme.of(context).textTheme.headlineMedium);
              },
            ),
            const SizedBox(height: 10),
            // 6. Use context.storeValue<T>() for a one-time read or with another builder.
            // This is useful for accessing a value without subscribing to its changes directly in this widget.
            Builder(builder: (context) {
              final count = context
                  .storeValue<int>('counter'); // Returns T? so handle null
              return Text('Counter (via context.storeValue): ${count ?? 'N/A'}',
                  textAlign: TextAlign.center);
            }),
            const SizedBox(height: 10),
            // 7. To observe a specific key from the store with a RefBuilder-like syntax:
            // First, get the Ref, then use its .obs extension or pass it to a RefBuilder.
            // Example using RefBuilder:
            // RefBuilder<int>(
            //   refValue: appState.getRef<int>('counter')!,
            //   builder: (context, count) {
            //     return Text('Counter (Store key .obs): ${count ?? 'N/A'}', textAlign: TextAlign.center);
            //   },
            // ),
            // Or, if Ref has an .obs extension that takes a builder:
            (appState.getRef<int>('counter')!).obs(builder: (context, count) {
              return Text('Counter (Store key .obs): $count',
                  textAlign: TextAlign.center);
            }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final currentCounter = appState.getValue<int>('counter') ?? 0;
          appState.setValue('counter', currentCounter + 1);
        },
        tooltip: 'Increment Counter',
        child: const Icon(Icons.add),
      ),
    );
  }
}
