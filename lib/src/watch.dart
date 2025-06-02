import 'interface.dart';
import 'watch_effect.dart';

// Add or replace existing definitions with these:

/// A function that converts a list of dynamic values into a strongly-typed Record.
///
/// - [R]: The Record type to convert to.
/// - [values]: A list of dynamic values from the reactive sources.
/// Returns an instance of [R].
typedef WatchRecordConverter<R extends Record> = R Function(
    List<dynamic> values);

/// A callback function for [watchMultiple] that receives the new and old values
/// as strongly-typed Records.
///
/// - [R]: The Record type representing the combined values.
/// - [newValues]: The new values of the watched sources, as a Record.
/// - [oldValues]: The old values of the watched sources, as a Record.
typedef WatchMultipleCallback<R extends Record> = void Function(
  R newValues,
  R oldValues,
);

/// Watches a reactive source ([RefBase]) and runs a callback function
/// when the source's value changes.
///
/// This function is similar to Vue's [watch] API. It immediately runs
/// a reactive effect that tracks the [source] as a dependency. When the
/// [source]'s value changes, the [callback] is invoked with the new and
/// old values.
///
/// {@tool snippet}
/// ```dart
/// final counter = ref(0);
///
/// final stopWatching = watch(
///   counter,
///   (newValue, oldValue) {
///     print('Counter changed from $oldValue to $newValue');
///   },
///   immediate: true, // Run callback immediately with initial value
/// );
///
/// counter.value++; // Triggers callback: "Counter changed from 0 to 1"
/// counter.value = 5; // Triggers callback: "Counter changed from 1 to 5"
///
/// stopWatching(); // Stop the watcher
/// counter.value = 10; // Callback will no longer be invoked
/// ```
/// {@end-tool}
///
/// - [source]: The [RefBase<T>] instance to watch.
/// - [callback]: A function of type [WatchCallback<T>] that will be executed
///   when the [source]'s value changes. It receives [(newValue, oldValue)].
/// - [immediate]: If `true`, the [callback] is run immediately upon creation
///   of the watcher. The `oldValue` will be `null` (or the initial value if
///   the source already had one and it's considered "old" for the first run)
///   in this initial call. Defaults to `false`.
/// - [deep]: If `true`, the watcher will attempt to track changes within
///   nested objects or collections if the [source] holds a [Map] or [List].
///   This is achieved by traversing the structure. Defaults to `false`.
///
/// Returns a [StopHandle] function that can be called to stop the watcher
/// and clean up its resources.
StopHandle watch<T>(
  RefBase<T> source,
  WatchCallback<T> callback, {
  bool immediate = false,
  bool deep = false,
}) {
  // Use WatchOptions from interface.dart
  final options = WatchOptions(immediate: immediate, deep: deep);
  T? oldValue = source
      .value; // Initialize oldValue with current value for correct first comparison if not immediate
  bool isFirstRun = true;

  // The runner function that will be executed by the watch effect.
  // ignore: prefer_function_declarations_over_variables
  final runner = () {
    final newValue = source.value;

    // If deep watching is enabled, traverse the new value to establish
    // dependencies on its internal structure if it's a Map or List.
    if (options.deep && (newValue is Map || newValue is List)) {
      _traverse(newValue);
    }

    // Call the callback if:
    // - It's not the first run (meaning a change has occurred after initial setup)
    // - OR it is the first run AND immediate option is true.
    // Also, ensure the value has actually changed to avoid redundant callbacks
    // if the effect is triggered but the value remains the same (though less common for simple refs).
    if (!isFirstRun || options.immediate) {
      if (isFirstRun && options.immediate) {
        // For immediate, oldValue for the very first call might be considered null
        // or the value itself if no "previous" state makes sense.
        // The current setup uses source.value at the start for oldValue.
        // Let's refine oldValue for the immediate first call.
        callback(newValue, isFirstRun && options.immediate ? null : oldValue);
      } else if (oldValue != newValue ||
          (options.deep && _didDeepChange(newValue, oldValue))) {
        // For subsequent runs, or non-immediate first run (which shouldn't happen here due to isFirstRun check),
        // only call if values are different.
        callback(newValue, oldValue);
      }
    }
    oldValue = newValue;
    isFirstRun = false;
  };

  // Create a watch effect that runs the runner.
  final effect = createWatchEffect(runner);

  // Run the effect once initially. This serves two purposes:
  // 1. If `immediate` is true, the callback will be executed.
  // 2. It establishes the initial dependency tracking.
  // The `runner` itself handles the logic for whether to call the user's callback.
  effect.run();

  // Return the stop function from the effect.
  return effect.stop;
}

/// Watches multiple reactive sources ([RefBase] instances) and runs a callback
/// function when any of the sources' values change.
///
/// {@tool snippet}
/// ```dart
/// final firstName = ref('John');
/// final lastName = ref('Doe');
/// final age = ref(30);
///
/// final stopWatching = watchMultiple(
///   [firstName, lastName, age],
///   (newValues, oldValues) {
///     print('Values changed:');
///     if (newValues[0] != oldValues[0]) print('  Name: ${oldValues[0]} -> ${newValues[0]}');
///     if (newValues[1] != oldValues[1]) print('  Last: ${oldValues[1]} -> ${newValues[1]}');
///     if (newValues[2] != oldValues[2]) print('  Age:  ${oldValues[2]} -> ${newValues[2]}');
///   },
///   immediate: true,
/// );
///
/// firstName.value = 'Jane'; // Triggers callback
/// age.value = 31;       // Triggers callback
///
/// stopWatching();
/// ```
/// {@end-tool}
///
/// - [sources]: A list of [RefBase<dynamic>] instances to watch.
/// - [callback]: A function that will be executed when any of the [sources]'
///   values change. It receives [(newValues, oldValues)], where each is a list
///   of current and previous values corresponding to the [sources] list.
/// - [immediate]: If `true`, the [callback] is run immediately. `oldValues`
///   will be a list of `null`s (or initial values) in this call. Defaults to `false`.
/// - [deep]: If `true`, performs deep watching on elements of [sources] that
///   are Maps or Lists. Defaults to `false`.
///
/// Returns a [StopHandle] function to stop the watcher.
StopHandle watchMultiple<R extends Record>(
  List<RefBase<dynamic>> sources,
  WatchRecordConverter<R> converter,
  WatchMultipleCallback<R> callback, {
  bool immediate = false,
  bool deep = false,
}) {
  final options = WatchOptions(immediate: immediate, deep: deep);
  // oldValues and newValues will be populated as List<dynamic> internally
  // and then converted to Record type R before invoking the callback.
  final List<dynamic> rawOldValues =
      List<dynamic>.filled(sources.length, null, growable: false);
  final List<dynamic> rawNewValues =
      List<dynamic>.filled(sources.length, null, growable: false);
  bool isFirstRun = true;

  // Initialize oldValues with current values for correct first comparison if not immediate
  if (!isFirstRun || !options.immediate) {
    for (int i = 0; i < sources.length; i++) {
      rawOldValues[i] = sources[i].value;
    }
  }

  // ignore: prefer_function_declarations_over_variables
  final runner = () {
    bool hasChangedOverall = false;

    for (int i = 0; i < sources.length; i++) {
      final source = sources[i];
      final currentValue = source.value;
      rawNewValues[i] = currentValue; // Store current value as new

      if (rawOldValues[i] != currentValue ||
          (options.deep && _didDeepChange(currentValue, rawOldValues[i]))) {
        hasChangedOverall = true;
      }

      if (options.deep && (currentValue is Map || currentValue is List)) {
        _traverse(currentValue);
      }
    }

    if ((hasChangedOverall && !isFirstRun) ||
        (isFirstRun && options.immediate)) {
      // For immediate first run, oldValues might be all nulls or pre-filled initial values.
      // The current setup pre-fills oldValues if not immediate first run.
      // For immediate, we want oldValues to represent a "before" state, often nulls.
      final R newRecord = converter(List.from(rawNewValues));
      final R oldRecord = converter(isFirstRun && options.immediate
              ? List<dynamic>.filled(sources.length,
                  null) // For immediate first run, old values are effectively nulls
              : List.from(
                  rawOldValues) // For subsequent runs, use captured old values
          );
      callback(newRecord, oldRecord);
    }

    // Update oldValues for the next run
    for (int i = 0; i < sources.length; i++) {
      rawOldValues[i] = rawNewValues[i];
    }

    isFirstRun = false;
  };

  final effect = createWatchEffect(runner);
  effect
      .run(); // Initial run to establish dependencies and trigger immediate callback if set

  return effect.stop;
}

/// Recursively traverses a value (Map or List) to ensure that changes
/// deep within its structure are tracked by the reactive system when `deep`
/// watching is enabled.
///
/// This function is called by [watch] and [watchMultiple] when `deep: true`.
/// By accessing each element/key-value pair, it registers them as dependencies
/// of the encompassing `WatchEffect`.
///
/// - [value]: The value to traverse. If it's a Map, its keys and values are
///   traversed. If it's a List, its items are traversed. Other types are ignored.
void _traverse(dynamic value) {
  if (value == null) return;

  // Keep track of visited objects to handle circular references.
  final Set<dynamic> visited = {};

  void performTraversal(dynamic current) {
    if (current == null || visited.contains(current)) {
      return;
    }
    visited.add(current);

    if (current is Map) {
      // Accessing entries to track them.
      for (final entry in current.entries) {
        performTraversal(entry.key); // Keys can also be complex objects
        performTraversal(entry.value);
      }
    } else if (current is List) {
      // Accessing items to track them.
      for (final item in current) {
        performTraversal(item);
      }
    }
    // For other types, accessing them (e.g., `current.toString()`) might trigger
    // tracking if they are themselves reactive, but simple _traverse usually
    // focuses on collections. The act of reading `source.value` in the runner
    // handles basic Ref tracking.
  }

  performTraversal(value);
}

/// Helper function to determine if a deep change occurred.
/// This is a placeholder and might need a more sophisticated implementation
/// for true deep equality checking, e.g., using `DeepCollectionEquality` from `package:collection`.
/// For now, it's a simple inequality check, which [_traverse] helps make more effective
/// by ensuring all parts of the object are "touched" by the effect.
bool _didDeepChange(dynamic newValue, dynamic oldValue) {
  // A more robust deep comparison would be needed here if _traverse wasn't
  // ensuring all parts are dependencies. For now, simple inequality is used,
  // relying on the effect system to pick up changes in traversed parts.
  if (newValue is Map && oldValue is Map) {
    // This is a naive check. Real deep equality is more complex.
    // Consider using package:collection's DeepCollectionEquality().
    return newValue.toString() != oldValue.toString(); // Placeholder
  }
  if (newValue is List && oldValue is List) {
    // This is a naive check. Real deep equality is more complex.
    return newValue.toString() != oldValue.toString(); // Placeholder
  }
  return newValue != oldValue;
}
