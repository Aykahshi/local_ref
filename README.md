# Local Ref - Simple, Powerful State Management for Dart & Flutter

[![pub version][pub_badge]][pub_link]
[![license][license_badge]][license_link]

A lightweight, intuitive, and powerful state management library for Dart and Flutter applications. Inspired by reactive programming principles, `local_ref` provides fine-grained reactivity with minimal boilerplate.

## Overview

`local_ref` offers a simple way to create observable values (`Ref`) and automatically react to their changes (`watchEffect`, `watchMultiple`). It also includes a `Store` for managing multiple named `Ref`s, and seamless integration with Flutter widgets for building reactive UIs.

The library is designed to be:
- **Simple & Intuitive**: Easy to learn and use, with a minimal API surface.
- **Powerful**: Supports complex reactive dependencies and transformations.
- **Lightweight**: No heavy dependencies, keeping your app lean.
- **Flexible**: Use it for local component state or for app-wide state management with providers.
- **Type-Safe**: Leverages Dart's strong typing, especially with the new Record types for `watchMultiple`.

## Features

- **`Ref<T>`**: Observable, reactive references for any data type.
- **`watchEffect`**: Automatically tracks `Ref` dependencies and re-runs a function when they change.
- **`watchMultiple`**: Observes a list of `Ref`s and triggers a callback with their new values, supporting type-safe conversion to Dart Records.
- **`Store`**: A centralized container to manage multiple named `Ref`s.
- **Flutter Integration**:
    - `RefBuilder`, `MultiRefBuilder`: Widgets that rebuild automatically when observed `Ref`s change.
    - `RefProvider`, `StoreProvider`: Easily provide `Ref`s or `Store`s to the widget tree using the `provider` package.
    - `RefConsumer`, `StoreConsumer`: Consume `Ref`s or `Store`s with dedicated consumer widgets.
    - `RefSelector`, `StoreSelector`: Select and listen to derived state from `Ref`s or `Store`s.
    - `BuildContext` extensions (`context.ref<T>()`, `context.store()`): Convenient access to provided state.

## Getting Started

### Installation

Add `local_ref` to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  local_ref: ^0.0.1
```

Then, run `flutter pub get`.

### Import

Import the library in your Dart files:

```dart
import 'package:local_ref/local_ref.dart';
```

## Core Concepts & Usage

### `ref(initialValue)`

Creates a reactive reference. Access its value using `.value`.

```dart
final counter = ref(0); // Creates a Ref<int>
print(counter.value); // Output: 0

counter.value++;
print(counter.value); // Output: 1
```

### `watchEffect(() { ... })`

Runs a function immediately and then re-runs it whenever any `Ref` accessed within it changes. Returns a `StopHandle` to stop the effect.

```dart
final name = ref('Guest');
final message = ref('Welcome');

// This effect will run initially, and then whenever name.value or message.value changes.
final stopEffect = watchEffect(() {
  print('${message.value}, ${name.value}!');
});

name.value = 'Alice'; // Effect re-runs: "Welcome, Alice!"
message.value = 'Hello'; // Effect re-runs: "Hello, Alice!"

// To stop the effect and clean up:
stopEffect();
```

### `watchMultiple<R extends Record>(List<RefBase> dependencies, R Function(List<dynamic> values) converter, ...)`

Watches a list of `Ref`s and calls a callback when any of them change. It supports a `converter` function to transform the list of raw values into a strongly-typed Dart Record. Returns a `StopHandle`.

```dart
final firstName = ref('John');
final lastName = ref('Doe');
final age = ref(30);

// Define the Record type for the callback
typedef UserRecord = ({String first, String last, int age});

final stopWatcher = watchMultiple<UserRecord>(
  dependencies: [firstName, lastName, age],
  converter: (values) {
    // values is List<dynamic> containing [firstName.value, lastName.value, age.value]
    return (
      first: values[0] as String,
      last: values[1] as String,
      age: values[2] as int,
    );
  },
  callback: (UserRecord newValues, UserRecord? oldValues, List<bool> didChange) {
    print('User updated: ${newValues.first} ${newValues.last}, Age: ${newValues.age}');
    if (oldValues != null) {
      print('Previous age: ${oldValues.age}');
    }
  },
  immediate: true, // Run callback immediately with initial values
);

firstName.value = 'Jane'; // Callback triggers
age.value = 31;       // Callback triggers

// To stop watching:
stopWatcher();
```

### `Store`

A `Store` is a convenient way to manage multiple named `Ref`s.

```dart
final appStore = Store();

// Register refs
appStore.register('counter', ref(0));
appStore.register('username', ref('Admin'));

// Access refs
final counterRef = appStore.getRef<int>('counter');
counterRef?.value++; // Increment counter

final username = appStore.getValue<String>('username');
print(username); // Output: Admin

// Dispose the store and all its refs when no longer needed
appStore.dispose();
```

## Flutter Integration

`local_ref` integrates smoothly with Flutter using the `provider` package under the hood for dependency injection.

### Providing State

Use `RefProvider` or `StoreProvider` (which are extensions of `ChangeNotifierProvider`) to make `Ref`s or `Store`s available to the widget tree.

```dart
// main.dart or a high-level widget
final counter = ref(0); // This is a Ref<int>
final myStore = Store()..register('message', ref('Hello from Store'));

void main() {
  runApp(
    MultiProvider( // Using MultiProvider from the provider package
      providers: [
        RefProvider<int>(ref: counter, child: const MyApp()), // Provide a single Ref
        // Or provide the store if MyApp or its descendants need it
        // StoreProvider(store: myStore, child: const MyApp()),
      ],
      child: const MyApp(), // Your actual app widget
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Example: If MyApp needs the store, it could be provided above instead.
    // For demonstration, we'll assume counter is used here.
    return StoreProvider(
      store: myStore, // Assuming myStore is accessible here or passed down
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Local Ref Demo')),
          // Body will be replaced by actual example pages navigation
          body: Center(child: Text('See example/ for detailed usage.')),
        ),
      ),
    );
  }
}
```
**Note on Lifecycle:** When providing `Ref`s or `Store`s created directly in `build` methods (especially in `StatelessWidget`s), their lifecycle isn't automatically managed if the provider is removed. For `Ref`s/`Store`s that need to persist, consider creating them in a `StatefulWidget`'s `State` and disposing them in `dispose`, or use the `.value` named constructor of `RefProvider` / `StoreProvider` for externally managed instances.

### Consuming State in Widgets

#### 1. `RefBuilder` & `MultiRefBuilder`

These widgets rebuild automatically when the observed `Ref`(s) change.

```dart
// Assuming 'counter' is a Ref<int> available in scope
RefBuilder<int>(
  ref: counter, 
  builder: (context, count, child) {
    return Text('Count: $count');
  },
);

// Assuming 'nameRef' is a Ref<String>
final nameRef = ref("User");
MultiRefBuilder<({int count, String name})>(
  dependencies: [counter, nameRef],
  converter: (values) => (count: values[0] as int, name: values[1] as String),
  builder: (context, data, child) {
    return Text('${data.name} clicked ${data.count} times');
  },
);
```

#### 2. `.obs()` Extension

A shorthand for creating a `RefBuilder` from a `Ref` instance.

```dart
counter.obs(builder: (context, count) { // counter is a Ref<int>
  return Text('Count (obs): $count');
})
```

#### 3. `RefConsumer` & `StoreConsumer`

Similar to `Consumer` from the `provider` package, but typed for `RefBase` and `Store`. These are useful when you only want to pass the value to the builder, not the `Ref` itself.

```dart
// Consuming a Ref<int> provided by RefProvider higher in the tree
RefConsumer<int>(
  builder: (context, countValue, child) { // countValue is int, not Ref<int>
    return Text('Consumed Count: $countValue');
  },
);

// Consuming a Store provided by StoreProvider
StoreConsumer(
  builder: (context, store, child) {
    final message = store.getValue<String>('message') ?? 'Default';
    return Text('Store Message: $message');
  },
);
```

#### 4. `RefSelector` & `StoreSelector`

Listen to a part of a `Ref`'s value or a derived value from a `Store`. This is useful for performance optimization, as the widget only rebuilds if the selected value changes.

```dart
// Example for RefSelector:
// class MyData { final String name; MyData(this.name); }
// final myDataRef = ref(MyData("initial name"));
// RefSelector<MyData, String>(
//   refValue: myDataRef, // This ref would typically be obtained from a provider or state
//   selector: (context, data) => data.name,
//   builder: (context, name, child) {
//     return Text('Data name: $name'); // Only rebuilds if name changes
//   },
// );

// Example with StoreSelector
StoreSelector<String>(
  selector: (context, store) => store.getValue<String>('message') ?? '',
  builder: (context, message, child) {
    return Text('Selected Message: $message');
  },
);
```

#### 5. `BuildContext` Extensions

Access provided `Ref`s and `Store`s easily.

```dart
// In a widget's build method:

// Get a Ref<int> (listens to changes by default)
final counterRefFromContext = context.ref<int>();
final countValue = counterRefFromContext.value;

// Get a Ref<int> without listening (e.g., for use in event handlers)
final currentCount = context.ref<int>(listen: false).value;

// Get the Store (listens to changes by default)
final appStoreFromContext = context.store();
final messageRefFromStore = appStoreFromContext.getRef<String>('message');

// Get a specific Ref from the store using context.storeRef
final specificRef = context.storeRef<String>('message');

// Get a value directly from a Ref in the store using context.storeValue
final specificValue = context.storeValue<String>('message');
```

## Examples

The `example/` directory contains a Flutter application showcasing:
- Local `Ref` usage within a widget (`LocalUsagePage`).
- `RefProvider` and `RefConsumer` pattern (`RefProviderPage`).
- `StoreProvider`, `StoreConsumer`, and `StoreSelector` patterns (`StoreProviderPage`).
- Usage of `watchEffect` and `watchMultiple`.

To run the example:
```bash
cd example
flutter pub get
flutter run -t example.dart -d chrome # or your preferred device
```

## API Documentation

For detailed API documentation, please visit the [package page on pub.dev][pub_link] (link will be active once published).

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue on the GitHub repository. If you'd like to contribute code, please fork the repository and submit a pull request.

## License

This package is licensed under the MIT License. See the `LICENSE` file for details.

[pub_badge]: https://img.shields.io/pub/v/local_ref.svg
[pub_link]: https://pub.dev/packages/local_ref
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[effective_dart_badge]: https://img.shields.io/badge/style-effective_dart-40c4ff.svg
[effective_dart_link]: https://github.com/tenhobi/effective_dart
