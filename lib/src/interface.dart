import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Defines the base interface for a reactive value container.
///
/// A `RefBase<T>` holds a value of type `T` and notifies its listeners
/// when the value changes. It extends [ChangeNotifier] from Flutter's
/// foundation library to leverage its notification mechanism, making it
/// suitable for integrating with Flutter widgets.
///
/// Implementations of this class, like [Ref] and [ComputedRef], provide
/// concrete ways to create and manage reactive state.
abstract class RefBase<T> extends ChangeNotifier {
  /// Gets the current value of this reactive reference.
  ///
  /// Accessing `value` in a reactive context (e.g., within a `watchEffect`
  /// or a `computed` getter) typically establishes a dependency on this reference.
  T get value;

  /// Sets a new value for this reactive reference.
  ///
  /// Assigning a new value will notify any listeners (including those
  /// established by `watch`, `watchEffect`, or UI widgets listening via
  /// [ChangeNotifier.addListener]) if the new value is different from the old one.
  set value(T newValue);
}

/// Defines the base interface for a reactive effect, similar to Vue's `watchEffect`.
///
/// A [WatchEffectBase] encapsulates a side effect (a function) that depends on
/// one or more reactive references. The effect automatically tracks these
/// dependencies and re-runs itself whenever any of the dependencies change.
abstract class WatchEffectBase {
  /// Executes the reactive effect.
  ///
  /// This method is called initially when the effect is created (if configured to do so)
  /// and subsequently whenever its tracked dependencies change.
  void run();

  /// Stops the reactive effect from tracking its dependencies and re-running.
  ///
  /// Once stopped, the effect will no longer execute, even if its
  /// previously tracked dependencies change. This is important for cleaning up
  /// resources and preventing memory leaks.
  void stop();
}

/// Defines options for configuring the behavior of a `watch` operation.
///
/// These options control aspects like when the callback is first executed
/// and how deeply nested objects are observed.
class WatchOptions {
  /// If `true`, the watch callback is executed immediately upon creation
  /// of the watcher, with the initial value(s) of the observed source(s).
  ///
  /// Defaults to `false`.
  final bool immediate;

  /// If `true`, the watcher will perform a deep comparison of nested objects
  /// or collections when detecting changes. This can be resource-intensive.
  ///
  /// Note: The actual implementation of "deep" watching might vary based on
  /// the specific `watch` function and the types being observed. It often
  /// implies that changes within complex objects (e.g., properties of an object
  /// within a `Ref<MyObject>`, or elements within a `Ref<List>`) trigger the
  /// callback, not just a change of the object reference itself.
  ///
  /// Defaults to `false`.
  final bool deep;

  /// Creates a [WatchOptions] instance.
  ///
  /// [immediate]: Whether to run the callback immediately. Defaults to `false`.
  /// [deep]: Whether to perform deep watching. Defaults to `false`.
  WatchOptions({
    this.immediate = false,
    this.deep = false,
  });
}

/// A function type representing a handle that can be called to stop a watcher
/// or a reactive effect.
///
/// Calling this function will typically unregister the associated callback
/// and clean up any resources used by the watcher/effect.
typedef StopHandle = void Function();

/// A callback function type used by watchers (e.g., created via `watch`).
///
/// This function is invoked when the observed reactive source(s) change.
/// It receives the [newValue] and the [oldValue] of the source.
/// For the initial call (if `immediate` is true in [WatchOptions]), [oldValue]
/// might be `null` or a specific sentinel indicating it's the first run.
typedef WatchCallback<T> = void Function(T newValue, T? oldValue);
