# ADB Studio
A desktop application built with **Flutter** for Windows to manage, inspect, and interact with Android devices via the Android Debug Bridge (ADB).

> This is a vibe-coded project, built entirely with AI assistance. I handled the design, while the logic was AI-generated and refined through iterative prompting. Use it or fork it.

## Key Features

* **Device Connection & Pairing**: Connect via USB, Wi-Fi pairing (QR code & PIN), discovery, and host network adapter inspection.
* **Device Information**: View real-time battery status, display properties, hardware details, build properties, and device uptime.
* **App Manager**: List installed system and user packages, search & filter apps, inspect permissions, launch apps, force stop,  and install APKs via drag-and-drop or file picker.
* **File Manager**: Explore Android device storage (`/sdcard`), browse directories, inspect file stats, create directories, and transfer files.
* **Screen Tools**: Capture screenshots and record device screens with direct export to the host PC.
* **ADB Command History**: Inspect all executed background ADB commands with status codes, outputs, and execution logs.

## Prerequisites & ADB Setup

1. **Flutter SDK**: Ensure Flutter is installed on your Windows system with desktop support enabled.
2. **Android SDK Platform-Tools (ADB)**:
   - Download the official package directly from [Android Developer Platform Tools](https://developer.android.com/tools/releases/platform-tools).
   - Extract the `platform-tools` folder to a convenient location on your PC (e.g., `C:\Android-SDK\platform-tools`.
   - Add the folder path to your Windows **System Environment Variables** (`PATH`), or configure the path directly in the application's connection settings.
   - Verify installation in terminal by running:
     ```bash
     adb version
     ```

## Phone Setup & Precautions

To connect your Android device:

1. **Enable Developer Options**: Go to **Settings > About Phone** and tap **Build Number** a few times until developer mode is unlocked.
2. **Enable USB Debugging**: Go to **Settings > System / Additional Settings > Developer Options** and enable **USB/Wireless Debugging**.
3. **Allow Access**: When connecting for the first time.

### ⚠️ Security Precautions

* **Public Networks**: Avoid enabling or keeping **Wireless Debugging** active on public or untrusted Wi-Fi networks (airports, cafes, public hotspots).
* **Turn Off When Done**: Toggle **USB Debugging** / **Wireless Debugging** (or entire **Developer Options**) off when not in use to prevent unauthorized host connections or unintended shell access.

## Getting Started
Make sure Flutter is installed on your system.
Clone the repo then `cd` into it and run the Flutter commands:

```bash
flutter pub get
flutter run -d windows
```


