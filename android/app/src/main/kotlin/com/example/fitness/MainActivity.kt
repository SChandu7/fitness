package com.example.fitness

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity (not FlutterActivity) is required by the `health` plugin:
 * Health Connect shows its permission screen through the AndroidX activity-result API.
 */
class MainActivity : FlutterFragmentActivity()
