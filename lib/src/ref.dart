import 'interface.dart'; // For RefBase
// ChangeNotifier is implicitly part of RefBase through interface.dart's extension or direct inheritance.

/// A reactive container for a single value.
///
/// A `Ref<T>` (or simply "ref") is a fundamental reactive primitive that holds a
/// value of type `T`. When the `value` of a `Ref` is changed, it automatically
/// notifies its listeners (e.g., UI widgets or computed properties that depend on it),
/// triggering re-renders or re-evaluations.
///
/// To create a `Ref`, use the [ref] factory function:
/// ```dart
/// final count = ref(0); // Creates a Ref<int> with initial value 0
/// print(count.value);   // Access the value: 0
///
/// count.value = 1;      // Change the value, listeners will be notified
/// print(count.value);   // Access the updated value: 1
/// ```
///
/// `Ref` extends [RefBase], which in turn is a [ChangeNotifier].
/// It uses `notifyListeners()` to signal changes.
class Ref<T> extends RefBase<T> {
  T _value;

  /// Creates a new reactive reference with an initial [initialValue].
  Ref(this._value);

  /// The current value of this reactive reference.
  ///
  /// Accessing this getter will allow reactive contexts (like `computed` or
  /// `watchEffect`) to track this `Ref` as a dependency if they call `trackRef`
  /// when accessing it.
  @override
  T get value => _value;

  /// Sets a new [newValue] for this reactive reference.
  ///
  /// If the [newValue] is different from the current value, this `Ref` will
  /// update its internal value and notify all registered listeners.
  @override
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }
}

/// Creates a new reactive reference ([Ref]) holding the given [initialValue].
///
/// A `Ref` is a reactive container whose `value` property can be read and written.
/// Changes to the `value` will trigger notifications to any listeners.
///
/// {@tool snippet}
/// ```dart
/// // Create a reactive integer
/// final counter = ref(0);
/// print(counter.value); // Output: 0
///
/// // Update the value
/// counter.value = 10;
/// print(counter.value); // Output: 10
///
/// // Example of listening to changes (e.g., in a widget or effect):
/// watchEffect(() {
///   print('Counter changed to: ${counter.value}');
/// });
/// counter.value = 20; // This would print "Counter changed to: 20"
/// ```
/// {@end-tool}
///
/// See also:
///  * [Ref], the class that this function instantiates.
///  * [computed], for creating derived reactive values.
Ref<T> ref<T>(T initialValue) {
  return Ref<T>(initialValue);
}
