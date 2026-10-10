# Boarding Manager

A Flutter app for managing a large boarding house: boarder registration and approval, monthly billing (rent, electricity, water), payments, and staff management.

## Features

**Manager**
- Approve or reject boarder signups
- Add and manage boarders and staff
- Record electricity and water readings
- Generate monthly bills and record payments

**Boarder**
- Sign up and wait for manager approval
- View personal information and monthly bills

**Planned**
- Online card payment
- Bank transfer slip upload with manager approval
- Complaint submission and tracking
- Backend API integration (shared data across devices)

## Tech stack

- Flutter (Dart)
- SQLite (`sqflite`) for local storage

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio (for the Android SDK and emulator)

### Run

```bash
git clone https://github.com/<your-username>/boarding_manager.git
cd boarding_manager
flutter pub get
flutter run
```

### Build an APK

```bash
flutter build apk --release --split-per-abi
```

The APK files are written to `build/app/outputs/flutter-apk/`.

## Project structure

```
lib/
  auth/        authentication logic
  models/      data models
  pages/       screens (manager and boarder)
  services/    database and API services
  main.dart    app entry point
```

## Status

Under active development as a university project.


