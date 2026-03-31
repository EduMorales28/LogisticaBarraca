#!/usr/bin/env bash
set -e
flutter pub get
flutter create .
flutter run -d chrome
