# FuelWise

A personal fuel-efficiency tracker **and** trip planner for Android, built with Flutter.

Log a fill-up (odometer + gallons + price) and FuelWise handles the rest — MPG,
cost per mile, spending trends, best-value stations, and trip estimates that run
on *your* real numbers. Data lives in a private GitHub repo (versioned backup +
cross-device sync) with a local cache so it keeps working while you're driving
out of signal.

## Status

Built in phases:

- **Phase 1 — foundation:** multi-vehicle fuel log, dashboard + trends, manual
  trip planner, GitHub data-sync, and CI that builds the APK onto a GitHub Release.
- **Phase 2 — Google Maps key:** live gas prices + fastest-vs-most-efficient routes.
- **Phase 3 — OBD-II dongle (Vgate iCar Pro BLE):** live per-trip fuel, automatic
  city/highway classification, and efficiency-aware route suggestions.

## How it's built

There is no local Android toolchain in the loop — **GitHub Actions builds the
signed APK in the cloud**. Push a `v*` tag and the workflow publishes an
installable APK to a GitHub Release; the app checks that same endpoint for updates.

The repo tracks `lib/`, `pubspec.yaml`, and assets; the `android/` project is
generated during CI (see [.github/workflows/build.yml](.github/workflows/build.yml)).

## Install

Grab the latest `fuelwise.apk` from the [Releases](../../releases) page and open it
on your Android phone (allow "install from this source" when prompted).
