import 'interface.dart'; // For WatchEffectBase, StopHandle

/// A global map that stores the dependencies for each reactive object.
///
/// The outer map's key is the reactive target object (e.g., a Ref instance).
/// The inner map's key is a property/key string of that target object (e.g., 'value' for a Ref).
/// The set contains all [WatchEffectBase] instances that depend on this specific property
/// of the target object.
///
/// Structure: `Map<ReactiveObject, Map<PropertyKey, Set<Effect>>>`
final Map<Object, Map<String, Set<WatchEffectBase>>> _targetMap = {};

/// The currently active effect that is being run.
///
/// When a [WatchEffectBase]'s [run()] method is executed, it sets itself
/// as the `_activeEffect`. Any reactive property accessed (tracked via [trackRef])
/// during the execution of this effect's function will register `_activeEffect`
/// as one of its dependents.
WatchEffectBase? _activeEffect;

/// Sets the currently active [WatchEffectBase].
///
/// This is called internally by [WatchEffectImpl.run] before executing the
/// effect's function, and reset to `null` after execution.
void setActiveEffect(WatchEffectBase? effect) {
  _activeEffect = effect;
}

/// Gets the currently active [WatchEffectBase].
///
/// This is used by [trackRef] to know which effect to associate with a
/// property access.
WatchEffectBase? getActiveEffect() {
  return _activeEffect;
}

/// Retrieves or creates the dependency map for a given [target] object.
///
/// The dependency map stores which effects are dependent on which properties
/// of the [target].
///
/// - [target]: The reactive object (e.g., a [RefBase] instance).
/// Returns a map where keys are property names and values are sets of
/// dependent [WatchEffectBase] instances.
Map<String, Set<WatchEffectBase>> getDepsMap(Object target) {
  return _targetMap.putIfAbsent(target, () => {});
}

/// Tracks a dependency between the currently active effect and a property
/// of a reactive object.
///
/// This function should be called whenever a reactive property is accessed
/// (e.g., reading `ref.value`). If there's an `_activeEffect` running,
/// this effect will be added to the list of dependencies for the
/// `target` object's `key` property.
///
/// - [target]: The reactive object whose property is being accessed.
/// - [key]: The name or key of the property being accessed (e.g., "value").
void trackRef(Object target, String key) {
  final effect = getActiveEffect();
  // Only track if there's an active effect.
  if (effect == null) return;

  final depsMap = getDepsMap(target);
  final deps = depsMap.putIfAbsent(key, () => {});

  // Add the effect to the set of dependencies for this target's key,
  // if it's not already there.
  if (!deps.contains(effect)) {
    deps.add(effect);
    // Future enhancement: an effect could also store which deps it has,
    // to make cleanupEffect more efficient, but current cleanup iterates _targetMap.
  }
}

/// Triggers all effects that depend on a specific property of a reactive object.
///
/// This function should be called whenever a reactive property is modified
/// (e.g., setting `ref.value = newValue`). It finds all [WatchEffectBase]
/// instances that were registered as dependents of the `target` object's `key`
/// property via [trackRef] and calls their [run()] method.
///
/// - [target]: The reactive object whose property was modified.
/// - [key]: The name or key of the property that was modified.
void triggerRef(Object target, String key) {
  final depsMap = getDepsMap(target);
  final deps = depsMap[key];

  if (deps != null && deps.isNotEmpty) {
    // Create a copy of the set before iterating.
    // This is important because an effect's run() method might itself
    // modify dependencies (e.g., if it stops itself or another effect),
    // which could lead to a ConcurrentModificationError if iterating over the original set.
    final effectsToRun = Set<WatchEffectBase>.from(deps);
    for (final effect in effectsToRun) {
      effect.run();
    }
  }
}

/// Cleans up an effect's dependencies.
///
/// When an effect is stopped (e.g., via [WatchEffectBase.stop]), this function
/// iterates through all known targets and their property dependencies in `_targetMap`
/// and removes the specified [effect] from their dependency sets.
/// This prevents the stopped effect from being triggered in the future and helps
/// avoid memory leaks.
///
/// - [effect]: The [WatchEffectBase] instance to remove from all dependency lists.
void cleanupEffect(WatchEffectBase effect) {
  // Iterate over a copy of keys if modification during iteration is possible,
  // though removing from a set while iterating its parent map's keys should be fine.
  for (final target in _targetMap.keys.toList()) {
    final depsMap = _targetMap[target]!; // Should exist if target is in keys
    for (final key in depsMap.keys.toList()) {
      final deps = depsMap[key];
      deps?.remove(effect);
    }
  }
}

/// Default implementation of the [WatchEffectBase] interface.
///
/// A [WatchEffectImpl] encapsulates a function (`_fn`) that contains reactive
/// dependencies. When [run()] is called, it sets itself as the `_activeEffect`,
/// executes `_fn` (during which dependencies are tracked via [trackRef]),
/// and then clears `_activeEffect`.
///
/// If any of its tracked dependencies change, [triggerRef] will cause its
/// [run()] method to be called again, re-evaluating the function and
/// re-tracking dependencies.
class WatchEffectImpl implements WatchEffectBase {
  final void Function() _fn;
  bool _active = true;

  /// Creates a [WatchEffectImpl] with the given function.
  /// - [_fn]: The function to execute as the effect. This function should
  ///   access reactive properties to establish dependencies.
  WatchEffectImpl(this._fn);

  @override
  void run() {
    if (!_active) return; // Do nothing if the effect has been stopped.

    try {
      // Set this effect as the active one so that any reactive property
      // accessed within _fn() will register this effect as a dependency.
      setActiveEffect(this);
      _fn(); // Execute the user-provided function.
    } finally {
      // Reset the active effect once execution is complete.
      setActiveEffect(null);
    }
  }

  @override
  void stop() {
    if (_active) {
      _active = false;
      // Remove this effect from all dependency lists to prevent it from
      // being run in the future and to allow for garbage collection.
      cleanupEffect(this);
    }
  }
}

/// Creates and returns a new [WatchEffectBase] instance.
///
/// The provided function [fn] will be wrapped in a [WatchEffectImpl].
/// The effect does not run automatically upon creation; you need to call
/// `effect.run()` to execute it for the first time and establish initial
/// dependencies. For an auto-running version, see [watchEffect].
///
/// {@tool snippet}
/// ```dart
/// final counter = ref(0);
///
/// // Create an effect that prints the counter's value.
/// final effect = createWatchEffect(() {
///   print('Counter value: ${counter.value}');
/// });
///
/// // Run the effect for the first time.
/// // Output: Counter value: 0
/// effect.run();
///
/// // Change the counter's value, which will trigger the effect.
/// // Output: Counter value: 1
/// counter.value = 1;
///
/// // Stop the effect.
/// effect.stop();
///
/// // Further changes to counter will not trigger the effect.
/// counter.value = 2; // No output
/// ```
/// {@end-tool}
///
/// - [fn]: The function to be executed by the effect.
/// Returns a [WatchEffectBase] instance.
WatchEffectBase createWatchEffect(void Function() fn) {
  final effect = WatchEffectImpl(fn);
  return effect;
}

/// Creates a reactive effect that runs immediately and re-runs automatically
/// whenever its dependencies change.
///
/// This function is similar to Vue's [watchEffect]. It takes a function [fn],
/// immediately executes it, and reactively tracks its dependencies. If any of
/// these dependencies change, [fn] is re-executed.
///
/// {@tool snippet}
/// ```dart
/// final name = ref('Guest');
///
/// // This effect runs immediately and prints the name.
/// // Output: Current name: Guest
/// final stopEffect = watchEffect(() {
///   print('Current name: ${name.value}');
/// });
///
/// // Changing the name will trigger the effect again.
/// // Output: Current name: John Doe
/// name.value = 'John Doe';
///
/// // Stop the effect from running further.
/// stopEffect();
///
/// name.value = 'Jane Doe'; // No output, as the effect is stopped.
/// ```
/// {@end-tool}
///
/// - [fn]: The function to execute. It will be run immediately and then
///   re-run whenever its tracked reactive dependencies change.
/// - [immediate]: If `true` (the default), the effect function [fn] is run
///   immediately upon creation. If `false`, it will only run when its
///   dependencies change for the first time (requires an initial `effect.run()`
///   or for [createWatchEffect] to be used and then [run()] called manually if
///   `immediate` is not desired from [watchEffect] itself).
///   *Note: The current implementation of [watchEffect] always creates the effect
///   and then conditionally runs it based on `immediate`. If `immediate` is false,
///   the effect is created but won't run until a dependency changes, or [run()] is
///   called on the underlying `WatchEffectBase` if it were exposed.*
///
/// Returns a [StopHandle] function that can be called to stop the effect
/// and clean up its dependencies.
StopHandle watchEffect(void Function() fn, {bool immediate = true}) {
  final effect = createWatchEffect(fn);

  if (immediate) {
    effect
        .run(); // Run the effect immediately to establish dependencies and execute fn.
  }
  // If not immediate, dependencies are only established when effect.run() is called.
  // The current API returns a StopHandle, so the user doesn't directly call run()
  // on the effect from this specific watchEffect() utility.
  // If `immediate` is false, this effect will essentially be dormant until a
  // dependency it *would* track (if it ran) changes, which is a bit unusual.
  // Typically, watchEffect implies an immediate run.
  // Consider if `immediate: false` should perhaps not call [run()] at all here,
  // and rely on the user to get the effect from [createWatchEffect] and run it.
  // However, the current structure is common.

  return effect.stop;
}
