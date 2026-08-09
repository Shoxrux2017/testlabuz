# TestLabUz Flutter Client

This directory contains the Flutter client scaffold and core application
infrastructure for TestLabUz.

## Tooling

- Flutter stable line: `3.44.x`
- Verified task SDK: `fvm spawn 3.44.7 --version`
- Dart is the version bundled with the selected Flutter SDK.

Use the FVM-managed SDK for Flutter commands:

```powershell
fvm spawn 3.44.7 pub get
fvm spawn 3.44.7 analyze
fvm spawn 3.44.7 test
fvm spawn 3.44.7 build windows --debug --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
fvm spawn 3.44.7 build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

Run formatting with the Dart executable from the same Flutter SDK:

```powershell
C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test
```

## API Configuration

The app requires a compile-time API base URL:

```powershell
fvm spawn 3.44.7 run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Android emulator local backend example:

```powershell
fvm spawn 3.44.7 run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`API_BASE_URL` must be an absolute `http` or `https` URI with no credentials,
query, or fragment, and its path must be `/api/v1`.
