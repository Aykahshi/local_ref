import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:local_ref/local_ref.dart'; // Assuming local_ref.dart exports 'watch' and 'StopHandle'

/// Builds a [StatefulWidget] that reacts to changes in a single [RefBase] instance.
///
/// When the [ref] changes, the [builder] function is called to rebuild
/// the widget tree.
///
/// {@tool snippet}
/// ```dart
/// final counter = ref(0);
///
/// class CounterDisplay extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return RefBuilder<int>(
///       refValue: counter,
///       builder: (context, value) {
///         return Text('Counter: $value');
///       },
///     );
///   }
/// }
///
/// // To use it:
/// MaterialApp(home: Scaffold(body: Center(child: CounterDisplay())));
/// // And then, elsewhere:
/// counter.value++; // This will trigger the RefBuilder to rebuild.
/// ```
/// {@end-tool}
///
/// See also:
///  * [MultiRefBuilder], for building widgets that depend on multiple [RefBase] instances.
///  * [RefWidgetX.obs], a convenient extension method to create a [RefBuilder].
class RefBuilder<T> extends StatefulWidget {
  /// The reactive [RefBase] instance to listen to.
  final RefBase<T> ref;

  /// A builder function that constructs the widget tree.
  ///
  /// It is called when [ref] changes.
  /// The [context] is the build context, and [value] is the current value of [ref].
  final Widget Function(BuildContext context, T value) builder;

  /// Creates a [RefBuilder] widget.
  ///
  /// The [key] is passed to the superclass.
  /// The [refValue] is the reactive state to observe.
  /// The [builder] function is responsible for building the widget based on the current [refValue].
  const RefBuilder({
    super.key,
    required this.ref,
    required this.builder,
  });

  @override
  State<RefBuilder<T>> createState() => _RefBuilderState<T>();
}

class _RefBuilderState<T> extends State<RefBuilder<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.ref.value;
    widget.ref.addListener(_onRefChanged);
  }

  void _onRefChanged() {
    if (mounted) {
      setState(() {
        _value = widget.ref.value;
      });
    }
  }

  @override
  void didUpdateWidget(covariant RefBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ref != oldWidget.ref) {
      oldWidget.ref.removeListener(_onRefChanged);
      _value = widget.ref.value;
      widget.ref.addListener(_onRefChanged);
    }
  }

  @override
  void dispose() {
    widget.ref.removeListener(_onRefChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value);
  }
}

/// A function that converts a list of dynamic values from observed [RefBase]
/// dependencies into a strongly-typed Record [R].
///
/// This is used by [MultiRefBuilder] to provide type-safe access to the values
/// of multiple reactive sources.
///
/// Example:
/// ```dart
/// // Assuming:
/// final nameRef = ref('Alice');
/// final ageRef = ref(30);
/// typedef UserRecord = ({String name, int age});
///
/// UserRecord userConverter(List<dynamic> values) {
///   return (name: values[0] as String, age: values[1] as int);
/// }
/// ```
typedef RecordConverter<R extends Record> = R Function(List<dynamic> values);

/// A builder function used by [MultiRefBuilder] that rebuilds its widget subtree
/// when any of the watched [RefBase] states change.
///
/// The [context] is the build context.
/// The [recordValues] is the strongly-typed [Record] (of type [R]) containing
/// the current values of all observed dependencies, as converted by a [RecordConverter].
typedef MultiRefWidgetBuilder<R extends Record> = Widget Function(
  BuildContext context,
  R recordValues,
);

/// Builds a [StatefulWidget] that reacts to changes in multiple [RefBase] sources,
/// providing type-safe access to their values via a Dart [Record].
///
/// [R] specifies the user-defined [Record] type that groups the values from the
/// [dependencies]. A [converter] function is used to map the list of dynamic
/// values from the dependencies to this strongly-typed record.
///
/// {@tool snippet}
/// ```dart
/// // Define reactive states
/// final firstName = ref('John');
/// final lastName = ref('Doe');
/// final age = ref(30);
///
/// // Define a record type
/// typedef UserProfileRecord = ({String firstName, String lastName, int age});
///
/// // Define a converter function
/// UserProfileRecord profileConverter(List<dynamic> values) {
///   return (
///     firstName: values[0] as String,
///     lastName: values[1] as String,
///     age: values[2] as int,
///   );
/// }
///
/// class UserProfileWidget extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return MultiRefBuilder<UserProfileRecord>(
///       dependencies: [firstName, lastName, age],
///       converter: profileConverter,
///       builder: (context, profile) {
///         return Column(
///           children: [
///             Text('First Name: ${profile.firstName}'),
///             Text('Last Name: ${profile.lastName}'),
///             Text('Age: ${profile.age}'),
///           ],
///         );
///       },
///     );
///   }
/// }
///
/// // To use it:
/// MaterialApp(home: Scaffold(body: Center(child: UserProfileWidget())));
/// // And then, elsewhere:
/// firstName.value = 'Jane'; // This will trigger MultiRefBuilder to rebuild.
/// ```
/// {@end-tool}
///
/// This widget uses the `watch` function internally to listen to changes in each dependency.
///
/// See also:
///  * [RefBuilder], for observing a single [RefBase].
///  * [MultiRefWidgetX.obs], a convenient extension method to create a [MultiRefBuilder].
class MultiRefBuilder<R extends Record> extends StatefulWidget {
  /// The list of [RefBase] dependencies to observe for changes.
  final List<RefBase<dynamic>> dependencies;

  /// Converts the raw list of values from [dependencies]
  /// into a strongly-typed [Record] of type [R].
  final RecordConverter<R> converter;

  /// Builder function that rebuilds when any of the [dependencies] change.
  /// The converted record [R] is passed for safe access.
  final MultiRefWidgetBuilder<R> builder;

  /// Creates a [MultiRefBuilder] widget.
  ///
  /// The [key] is passed to the superclass.
  /// [dependencies] are the list of reactive states to observe.
  /// [converter] transforms the values from [dependencies] into a typed [Record].
  /// [builder] builds the widget tree based on the converted record.
  const MultiRefBuilder({
    super.key,
    required this.dependencies,
    required this.converter,
    required this.builder,
  });

  @override
  State<MultiRefBuilder<R>> createState() => _MultiRefBuilderState<R>();
}

class _MultiRefBuilderState<R extends Record>
    extends State<MultiRefBuilder<R>> {
  /// Current snapshot of all dependency values.
  late List<dynamic> _currentValues;

  /// Stores stop handles for all active listeners.
  final List<StopHandle> _stopHandles = [];

  @override
  void initState() {
    super.initState();
    _initializeStatesAndSubscribe();
  }

  void _initializeStatesAndSubscribe() {
    // Initialize current values from dependencies
    _currentValues =
        widget.dependencies.map((dep) => dep.value).toList(growable: false);
    _subscribeToDependencies();
  }

  void _subscribeToDependencies() {
    // Clear any existing listeners first (e.g., if called from didUpdateWidget)
    _unsubscribeAll();

    for (int i = 0; i < widget.dependencies.length; i++) {
      final dep = widget.dependencies[i];
      final index = i; // Capture index for the closure

      // Using watch from local_ref.dart to listen to changes
      final stopHandle = watch(
        dep, // Source to watch
        (newValue, oldValue) {
          // Callback when the source changes
          if (mounted) {
            setState(() {
              // Ensure _currentValues is still valid and has the correct length
              if (index < _currentValues.length) {
                _currentValues[index] = newValue;
              } else {
                // This case should ideally be handled by robust re-initialization
                // if the structure of dependencies changes significantly.
                // For now, this ensures no out-of-bounds access.
                // Consider logging or a more sophisticated recovery if this path is hit.
              }
            });
          }
        },
        immediate:
            false, // Values are already initialized in _initializeStatesAndSubscribe
      );
      _stopHandles.add(stopHandle);
    }
  }

  void _unsubscribeAll() {
    for (final stopHandle in _stopHandles) {
      stopHandle();
    }
    _stopHandles.clear();
  }

  @override
  void didUpdateWidget(MultiRefBuilder<R> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the dependencies list itself (by reference or content)
    // or the converter function has changed.
    if (!listEquals(widget.dependencies, oldWidget.dependencies) ||
        widget.converter != oldWidget.converter) {
      // If they changed, re-initialize everything: current values and subscriptions.
      _initializeStatesAndSubscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Defensive check: Ensure _currentValues has the correct length.
    // This might be redundant if didUpdateWidget correctly handles all cases,
    // but serves as a safeguard.
    if (_currentValues.length != widget.dependencies.length) {
      _currentValues =
          widget.dependencies.map((dep) => dep.value).toList(growable: false);
    }
    final R recordValues = widget.converter(_currentValues);
    return widget.builder(context, recordValues);
  }
}

/// Extension methods for [RefBase] to easily create reactive widgets.
extension RefWidgetX<T> on RefBase<T> {
  /// Creates a [RefBuilder] widget that rebuilds when this [RefBase] changes.
  ///
  /// This is a convenience method for [RefBuilder(refValue: this, builder: builder)].
  ///
  /// {@tool snippet}
  /// ```dart
  /// final name = ref("Guest");
  ///
  /// class GreetingWidget extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     // Use the .obs() extension method
  ///     return name.obs(
  ///       builder: (context, currentName) {
  ///         return Text('Hello, $currentName!');
  ///       },
  ///     );
  ///   }
  /// }
  ///
  /// // To use it:
  /// MaterialApp(home: Scaffold(body: Center(child: GreetingWidget())));
  /// // And then, elsewhere:
  /// name.value = 'John'; // This will trigger the widget to rebuild.
  /// ```
  /// {@end-tool}
  ///
  /// The [key] is optional.
  /// The [builder] function takes the [BuildContext] and the current [value] of this [RefBase].
  RefBuilder<T> obs({
    Key? key,
    required Widget Function(BuildContext context, T value) builder,
  }) {
    return RefBuilder<T>(
      key: key,
      ref: this, // `this` refers to the RefBase instance
      builder: builder,
    );
  }
}

extension MultiRefWidgetX<R extends Record> on List<RefBase> {
  /// Creates a [MultiRefBuilder] widget that rebuilds when any of the [RefBase]
  /// instances in this list change.
  ///
  /// This is a convenience method for [MultiRefBuilder(dependencies: this, ... )].
  ///
  /// {@tool snippet}
  /// ```dart
  /// final firstName = ref('John');
  /// final age = ref(30);
  /// typedef ProfileRecord = ({String name, int age});
  ///
  /// class ProfileView extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return [firstName, age].obs<ProfileRecord>(
  ///       converter: (values) => (name: values[0] as String, age: values[1] as int),
  ///       builder: (context, profile) {
  ///         return Text('${profile.name} is ${profile.age}');
  ///       },
  ///     );
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  // ignore: avoid_shadowing_type_parameters
  MultiRefBuilder<R> obs<R extends Record>({
    Key? key,
    required RecordConverter<R> converter,
    required MultiRefWidgetBuilder<R> builder,
  }) {
    return MultiRefBuilder<R>(
      key: key,
      dependencies: this,
      converter: converter,
      builder: builder,
    );
  }
}
