```dart
import 'package:local_ref/local_ref.dart';

void main() {
  // 1. Create a Ref<int> with an initial value of 0
  final counter = ref(0);

  // 2. Read the value of the Ref
  print('Initial counter value: ${counter.value}'); // Output: Initial counter value: 0

  // 3. Modify the value of the Ref
  counter.value++;
  print('Counter value after increment: ${counter.value}'); // Output: Counter value after increment: 1

  // 4. Use watchEffect to listen for changes to the Ref
  // watchEffect runs once immediately, then again whenever counter.value changes
  final stopEffect = watchEffect(() {
    print('watchEffect: Counter is now ${counter.value}');
  });
  // Initial execution output: watchEffect: Counter is now 1

  // Modify the Ref's value again
  counter.value = 5;
  // watchEffect runs again, output: watchEffect: Counter is now 5

  // 5. Stop the watchEffect (if no longer needed)
  stopEffect();

  // Modify the value, watchEffect will no longer run
  counter.value = 10;
  print('Counter value after stopping effect: ${counter.value}'); // Output: Counter value after stopping effect: 10
}
```