import 'package:flutter/foundation.dart' show ChangeNotifier, VoidCallback;

import 'interface.dart'; // For RefBase

/// A repository for managing multiple reactive values ([RefBase] instances),
/// suitable for use as a data source with Flutter's Provider package or similar
/// state management solutions.
///
/// The [Store] itself is a [ChangeNotifier]. It listens to changes in its
/// registered [RefBase] instances. When any of these registered refs change,
/// the [Store] notifies its own listeners. This allows widgets to listen to
/// the [Store] and react to changes in any of the underlying reactive values
/// it manages.
///
/// {@tool snippet}
/// ```dart
/// final store = Store();
/// final counter = ref(0);
/// final name = ref('Guest');
///
/// store.register('counter', counter);
/// store.register('name', name);
///
/// // Later, in a widget, you might use StoreProvider:
/// // StoreProvider(store: store, child: ...);
///
/// // And in a descendant widget:
/// // final storeInstance = context.watch<Store>();
/// // final currentCount = storeInstance.getValue<int>('counter');
/// // if (storeInstance.hasChanged('counter')) {
/// //   print('Counter changed!');
/// //   storeInstance.clearChanged('counter');
/// // }
/// ```
/// {@end-tool}
class Store extends ChangeNotifier {
  final Map<String, RefBase<dynamic>> _refs = {};
  final Map<String, VoidCallback> _listeners =
      {}; // Stores the actual listeners
  final Set<String> _changedRefs = {};
  bool _disposed = false;

  /// Creates a new [Store] instance.
  Store();

  /// Registers a [RefBase<T>] instance with the store under the given [key].
  ///
  /// If a ref with the same [key] already exists, this operation is a no-op.
  /// The store will listen to changes in the [refValue]. When [refValue] changes,
  /// the store marks the [key] as changed and notifies its own listeners.
  ///
  /// - [key]: A unique string identifier for the reactive value.
  /// - [refValue]: The [RefBase<T>] instance to register.
  void register<T>(String key, RefBase<T> refValue) {
    if (_disposed) {
      // Optionally, throw an error or log a warning if trying to use a disposed store.
      // print('Warning: Store is disposed. Cannot register ref for key "$key".');
      return;
    }

    if (!_refs.containsKey(key)) {
      _refs[key] = refValue;

      // Create and store the listener for this specific refValue and key.
      // ignore: prefer_function_declarations_over_variables
      VoidCallback listener = () {
        if (_disposed) return;
        // Don't do anything if the store itself is disposed.
        _changedRefs.add(key);
        notifyListeners(); // Notify listeners of the Store.
      };
      _listeners[key] = listener;
      refValue.addListener(listener);
    }
  }

  /// Unregisters a [RefBase] instance associated with the given [key] from the store.
  ///
  /// This removes the ref from the store's internal tracking and also removes
  /// the listener that the store had attached to it.
  ///
  /// - [key]: The key of the reactive value to unregister.
  void unregister(String key) {
    if (_disposed) return;

    final refValue = _refs.remove(key);
    final listener = _listeners.remove(key);

    if (refValue != null && listener != null) {
      refValue.removeListener(listener);
    }
    _changedRefs.remove(key); // Also clear its changed status
  }

  /// Retrieves the [RefBase<T>] instance associated with the given [key].
  ///
  /// Returns `null` if no ref is found for the [key], if the store is disposed,
  /// or if the found ref is not of type `RefBase<T>`.
  ///
  /// - [key]: The key of the reactive value to retrieve.
  RefBase<T>? getRef<T>(String key) {
    if (_disposed) return null;

    final refValue = _refs[key];
    if (refValue != null && refValue is RefBase<T>) {
      return refValue;
    }
    return null;
  }

  /// Retrieves the current value of the [RefBase<T>] associated with the given [key].
  ///
  /// This is a convenience method that calls [getRef] and then accesses its [value].
  /// Returns `null` if the ref is not found or if the store is disposed.
  ///
  /// - [key]: The key of the reactive value whose actual value is to be retrieved.
  T? getValue<T>(String key) {
    final refValue = getRef<T>(key);
    return refValue?.value;
  }

  /// Sets the value of the [RefBase<T>] associated with the given [key].
  ///
  /// If no ref is found for the [key] or if the store is disposed, this method does nothing.
  ///
  /// - [key]: The key of the reactive value to update.
  /// - [value]: The new value to set.
  void setValue<T>(String key, T value) {
    if (_disposed) return;
    final refValue = getRef<T>(key);
    if (refValue != null) {
      refValue.value = value;
    }
  }

  /// Checks if the reactive value associated with the [key] has changed
  /// since the last time its changed status was cleared (or since it was registered).
  ///
  /// The "changed" status is typically set when the registered ref notifies the store
  /// of a change. It can be cleared using [clearChanged] or [clearAllChanged].
  ///
  /// - [key]: The key of the reactive value to check.
  /// Returns `true` if changed, `false` otherwise.
  bool hasChanged(String key) {
    if (_disposed) return false;
    return _changedRefs.contains(key);
  }

  /// Clears the "changed" status for the reactive value associated with [key].
  ///
  /// - [key]: The key whose changed status should be cleared.
  void clearChanged(String key) {
    if (_disposed) return;
    _changedRefs.remove(key);
  }

  /// Clears the "changed" status for all registered reactive values.
  void clearAllChanged() {
    if (_disposed) return;
    _changedRefs.clear();
  }

  /// Gets a set of keys for all reactive values that are currently marked as "changed".
  /// Returns an empty set if the store is disposed.
  Set<String> get changedKeys {
    if (_disposed) return {};
    return Set.from(_changedRefs);
  }

  /// Gets a set of all keys for reactive values currently registered in the store.
  /// Returns an empty set if the store is disposed.
  Set<String> get keys {
    if (_disposed) return {};
    return _refs.keys.toSet();
  }

  /// Disposes of the store and cleans up its resources.
  ///
  /// This involves:
  /// - Marking the store as disposed to prevent further operations.
  /// - Removing all listeners that the store had attached to its registered refs.
  /// - Clearing all internal collections.
  /// - Calling `super.dispose()` to notify any listeners of the store itself.
  ///
  /// Once disposed, most methods will have no effect or return default values
  /// (e.g., `null` or empty collections).
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Remove all listeners correctly
    for (final entry in _refs.entries) {
      final refValue = entry.value;
      final listener = _listeners[entry.key];
      if (listener != null) {
        // It's good practice to check if the listener exists before removing,
        // though in a correct implementation, it always should if the ref exists.
        refValue.removeListener(listener);
      }
    }

    _listeners.clear();
    _refs.clear();
    _changedRefs.clear();

    super.dispose();
  }
}

/// A factory function to create a new [Store] instance.
///
/// This provides a simple way to instantiate a [Store].
///
/// {@tool snippet}
/// ```dart
/// final myStore = createStore();
/// myStore.register('version', ref('1.0.0'));
/// ```
/// {@end-tool}
Store createStore() {
  return Store();
}
