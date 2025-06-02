// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'interface.dart';
import 'store.dart';

/// A [ChangeNotifierProvider] specifically designed for providing a [RefBase<T>]
/// to the widget tree.
///
/// This allows descendant widgets to access and listen to a [RefBase<T>] instance
/// using `Provider.of<RefBase<T>>(context)` or the `context.ref<T>()` extension.
///
/// {@tool snippet}
/// ```dart
/// final counter = ref(0); // Your RefBase<int> instance
///
/// // In your widget tree:
/// RefProvider<int>(
///   refValue: counter,
///   child: YourConsumingWidget(),
/// );
///
/// // In YourConsumingWidget:
/// // final countRef = context.watch<RefBase<int>>();
/// // Text('Count: ${countRef.value}');
/// ```
/// {@end-tool}
class RefProvider<T> extends ChangeNotifierProvider<RefBase<T>> {
  /// Creates a [RefProvider] that manages the lifecycle of the [ref].
  ///
  /// The [ref] is created via the `create` callback of [ChangeNotifierProvider].
  /// Use this constructor if the [RefProvider] itself should own the [ref].
  RefProvider({
    Key? key,
    required RefBase<T> ref,
    required Widget child,
  }) : super(
          key: key,
          create: (_) => ref,
          child: child,
        );

  /// Creates a [RefProvider] using an existing [ref].
  ///
  /// The [ref] is provided directly using the `ChangeNotifierProvider.value`
  /// constructor. Use this if the [ref] is managed外部 and its lifecycle
  /// is not tied to this provider.
  static Widget value<T>({
    Key? key,
    required RefBase<T> ref,
    required Widget child,
  }) {
    return ChangeNotifierProvider<RefBase<T>>.value(
      key: key,
      value: ref,
      child: child,
    );
  }
}

/// A [ChangeNotifierProvider] specifically designed for providing a [Store]
/// to the widget tree.
///
/// This allows descendant widgets to access and listen to a [Store] instance
/// using `Provider.of<Store>(context)` or the `context.store()` extension.
///
/// {@tool snippet}
/// ```dart
/// final myStore = Store(); // Your Store instance
/// myStore.register('counter', ref(0));
///
/// // In your widget tree:
/// StoreProvider(
///   store: myStore,
///   child: YourConsumingWidget(),
/// );
///
/// // In YourConsumingWidget:
/// final store = context.watch<Store>();
/// final countRef = store.getRef<int>('counter');
/// Text('Count: ${countRef?.value ?? 0}');
/// ```
/// {@end-tool}
class StoreProvider extends ChangeNotifierProvider<Store> {
  /// Creates a [StoreProvider] that manages the lifecycle of the [store].
  ///
  /// The [store] is created via the `create` callback of [ChangeNotifierProvider].
  /// Use this constructor if the [StoreProvider] itself should own the [store].
  StoreProvider({
    Key? key,
    required Store store,
    required Widget child,
  }) : super(
          key: key,
          create: (_) => store,
          child: child,
        );

  /// Creates a [StoreProvider] using an existing [store].
  ///
  /// The [store] is provided directly using the `ChangeNotifierProvider.value`
  /// constructor. Use this if the [store] is managed externally and its lifecycle
  /// is not tied to this provider.
  static Widget value({
    Key? key,
    required Store store,
    required Widget child,
  }) {
    return ChangeNotifierProvider<Store>.value(
      key: key,
      value: store,
      child: child,
    );
  }
}

/// A [Consumer] widget for a [RefBase<T>].
///
/// This widget simplifies listening to a [RefBase<T>] from the widget tree
/// and rebuilding when its value changes. It directly provides the unwrapped
/// value `T` to the builder.
///
/// {@tool snippet}
/// ```dart
/// // Assuming RefProvider<int>(refValue: counter, ...) is above in the tree.
/// RefConsumer<int>(
///   builder: (context, countValue, child) {
///     return Text('Count: $countValue');
///   },
/// );
/// ```
/// {@end-tool}
class RefConsumer<T> extends Consumer<RefBase<T>> {
  /// Creates a [RefConsumer].
  ///
  /// The [builder] function is called whenever the [RefBase<T>]'s value changes.
  /// It receives the build context, the unwrapped value `T`, and an optional [child] widget.
  RefConsumer({
    Key? key,
    required Widget Function(BuildContext context, T value, Widget? child)
        builder,
    Widget? child,
  }) : super(
          key: key,
          builder: (context, refValue, child) =>
              builder(context, refValue.value, child),
          child: child,
        );
}

/// A [Consumer] widget for a [Store].
///
/// This widget simplifies listening to a [Store] instance from the widget tree
/// and rebuilding when the [Store] notifies listeners (e.g., when refs are added/removed
/// or the store itself calls `notifyListeners`).
///
/// {@tool snippet}
/// ```dart
/// // Assuming StoreProvider(store: myStore, ...) is above in the tree.
/// StoreConsumer(
///   builder: (context, store, child) {
///     final counter = store.getRef<int>('counter');
///     return Text('Counter from store: ${counter?.value ?? 'N/A'}');
///   },
/// );
/// ```
/// {@end-tool}
class StoreConsumer extends Consumer<Store> {
  /// Creates a [StoreConsumer].
  ///
  /// The [builder] function is called whenever the [Store] notifies its listeners.
  StoreConsumer({
    Key? key,
    required Widget Function(BuildContext context, Store store, Widget? child)
        builder,
    Widget? child,
  }) : super(
          key: key,
          builder: builder,
          child: child,
        );
}

/// A [Selector] widget for a [RefBase<T>].
///
/// This widget allows selecting a specific part or derived value `S` from a
/// [RefBase<T>]'s value `T`. The [builder] only rebuilds if the selected
/// value `S` changes. This can be more efficient than [RefConsumer] if you
/// only depend on a small part of a larger reactive state.
///
/// {@tool snippet}
/// ```dart
/// // final userRef = ref(User(name: 'Alice', age: 30)); // Assuming User class
/// // Assuming RefProvider<User>(refValue: userRef, ...) is above.
///
/// RefSelector<User, String>(
///   selector: (userValue) => userValue.name, // Select the name
///   builder: (context, userName, child) {
///     return Text('User name: $userName'); // Only rebuilds if name changes
///   },
/// );
/// ```
/// {@end-tool}
class RefSelector<T, S> extends Selector<RefBase<T>, S> {
  /// Creates a [RefSelector].
  ///
  /// [selector]: A function that extracts a value `S` from the [RefBase<T>]'s value `T`.
  /// [builder]: Called when the selected value `S` changes.
  /// [shouldRebuild]: Optional function to further control when [builder] is called.
  RefSelector({
    Key? key,
    required S Function(T value) selector,
    required Widget Function(
            BuildContext context, S selectedValue, Widget? child)
        builder,
    Widget? child,
    bool Function(S previous, S next)? shouldRebuild,
  }) : super(
          key: key,
          selector: (context, refValue) => selector(refValue.value),
          builder: builder,
          child: child,
          shouldRebuild: shouldRebuild,
        );
}

/// A [Selector] widget for a [Store].
///
/// This widget allows selecting a specific part or derived value `S` from a [Store].
/// The [builder] only rebuilds if the selected value `S` changes.
///
/// {@tool snippet}
/// ```dart
/// // Assuming StoreProvider(store: myStore, ...) is above.
/// // myStore.register('user', ref(User(name: 'Bob', age: 25)));
///
/// StoreSelector<String>(
///   selector: (context, store) {
///     final user = store.getValue<User>('user');
///     return user?.name ?? 'Unknown';
///   },
///   builder: (context, userName, child) {
///     return Text('User name from store: $userName');
///   },
/// );
/// ```
/// {@end-tool}
class StoreSelector<S> extends Selector<Store, S> {
  /// Creates a [StoreSelector].
  ///
  /// [selector]: A function that extracts a value `S` from the [Store].
  /// [builder]: Called when the selected value `S` changes.
  /// [shouldRebuild]: Optional function to further control when [builder] is called.
  StoreSelector({
    Key? key,
    required S Function(BuildContext context, Store store) selector,
    required Widget Function(
            BuildContext context, S selectedValue, Widget? child)
        builder,
    Widget? child,
    bool Function(S previous, S next)? shouldRebuild,
  }) : super(
          key: key,
          selector: selector,
          builder: builder,
          child: child,
          shouldRebuild: shouldRebuild,
        );
}

/// Extension methods on [BuildContext] for easier access to [RefBase<T>] and [Store]
/// instances provided via [Provider].
extension BuildContextExtension on BuildContext {
  /// Obtains a [RefBase<T>] from the nearest [RefProvider<T>] ancestor.
  ///
  /// By default, [listen] is `true`, meaning this widget will rebuild when
  /// the [RefBase<T>] notifies listeners. Set [listen] to `false` to access
  /// the value without subscribing to changes (e.g., in event handlers).
  ///
  /// Example:
  /// ```dart
  /// // Inside a widget:
  /// final counterRef = context.ref<int>(); // Listens to changes
  /// final currentValue = context.ref<int>(listen: false).value; // Just reads value
  /// ```
  RefBase<T> ref<T>({bool listen = true}) {
    return Provider.of<RefBase<T>>(this, listen: listen);
  }

  /// Obtains a [Store] from the nearest [StoreProvider] ancestor.
  ///
  /// By default, [listen] is `true`, meaning this widget will rebuild when
  /// the [Store] notifies listeners. Set [listen] to `false` to access
  /// the store without subscribing to changes.
  ///
  /// Example:
  /// ```dart
  /// // Inside a widget:
  /// final myStore = context.store(); // Listens to changes
  /// final anotherStore = context.store(listen: false); // Access without listening
  /// ```
  Store store({bool listen = true}) {
    return Provider.of<Store>(this, listen: listen);
  }

  /// Obtains a specific [RefBase<T>] identified by [key] from the [Store].
  ///
  /// This is a convenience method that first gets the [Store] using `context.store()`
  /// and then calls `store.getRef<T>(key)`.
  /// The [listen] parameter controls whether listening to the [Store] itself occurs,
  /// not necessarily the returned [RefBase<T>]. To listen to the specific ref,
  /// use `context.watch()` or [RefConsumer] with the result.
  ///
  /// Example:
  /// ```dart
  /// // Inside a widget:
  /// final userRef = context.storeRef<User>('currentUser');
  /// // To listen to userRef changes, you'd typically then use it in a RefConsumer/RefSelector
  /// // or context.watch() if userRef itself is a ChangeNotifier.
  /// ```
  RefBase<T>? storeRef<T>(String key, {bool listen = true}) {
    final storeInstance = store(listen: listen); // Listening to the store
    return storeInstance.getRef<T>(key);
  }

  /// Obtains the value of a specific [RefBase<T>] identified by [key] from the [Store].
  ///
  /// This is a convenience method that first gets the [Store] using `context.store()`
  /// and then calls `store.getValue<T>(key)`.
  /// The [listen] parameter controls whether listening to the [Store] itself occurs.
  /// This method does not establish a direct reactive link to the ref's value for rebuilding;
  /// for that, use [storeRef] and then consume the ref, or use [RefSelector]/[StoreSelector].
  ///
  /// Example:
  /// ```dart
  /// // Inside a widget, perhaps in an event handler:
  /// final currentUserName = context.storeValue<String>('userName', listen: false);
  /// ```
  T? storeValue<T>(String key, {bool listen = true}) {
    final storeInstance = store(listen: listen); // Listening to the store
    return storeInstance.getValue<T>(key);
  }
}
