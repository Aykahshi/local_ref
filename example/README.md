# Local Ref - Example Application

This directory contains a Flutter example application demonstrating the various features of the `local_ref` package.

## Overview

The example app showcases:
-   **Local `Ref` Usage**: How to use `ref()` and `watchEffect()` for managing state within a single widget.
-   **`RefProvider`**: Demonstrates providing a single `Ref` to a subtree and consuming it with `RefConsumer` and `context.ref()`.
-   **`StoreProvider`**: Shows how to provide a `Store` (a collection of named `Ref`s) and consume its state using `StoreConsumer`, `StoreSelector`, and `context.store()`.
-   Reactive UI updates with `RefBuilder`, `MultiRefBuilder`, and the `.obs()` extension.

## Structure

-   `example.dart`: The main entry point of the application. It sets up navigation to different example pages.
-   **Pages**:
    -   `HomePage`: Provides navigation to the different example scenarios.
    -   `LocalUsagePage`: Demonstrates local state management with `ref()` and `watchEffect()`.
    -   `RefProviderPage`: Shows how to use `RefProvider` to provide a `Ref<int>` (a counter).
    -   `StoreProviderPageWrapper` & `StoreProviderPage`: Illustrate using `StoreProvider` to manage multiple pieces of state (counter, name, dark mode).

## How to Run

1.  Ensure you have Flutter installed.
2.  Navigate to the `example` directory in your terminal:
    ```bash
    cd path/to/local_ref/example
    ```
3.  Get dependencies:
    ```bash
    flutter pub get
    ```
4.  Run the application:
    ```bash
    flutter run -d chrome
    ```
    (You can replace `chrome` with your preferred device ID, e.g., `iphone`, `android`, `windows`, `macos`, `linux`.)

This will launch the example app, allowing you to interact with the different demonstrations of `local_ref`'s capabilities.