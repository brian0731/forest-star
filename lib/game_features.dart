import 'package:flutter/foundation.dart';

// The iOS release temporarily excludes draws while purchasing is unavailable.
bool get drawsEnabled => kIsWeb || defaultTargetPlatform != TargetPlatform.iOS;
