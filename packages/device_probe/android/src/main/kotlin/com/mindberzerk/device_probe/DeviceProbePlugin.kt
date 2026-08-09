package com.mindberzerk.device_probe

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Plugin entry point. Registered automatically by Flutter's plugin loader from
 * the `pluginClass` in pubspec.yaml.
 *
 * No Activity binding. Every probe here reads from the application context, so
 * the plugin works from a background isolate and from a headless worker, which
 * matters for the launcher's desklets.
 */
class DeviceProbePlugin : FlutterPlugin {

    private var binaryMessenger: io.flutter.plugin.common.BinaryMessenger? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binaryMessenger = binding.binaryMessenger
        DeviceProbeHostApi.setUp(
            binding.binaryMessenger,
            DeviceProbeHostApiImpl(binding.applicationContext),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Clearing the handler is not optional. A hot restart attaches a new
        // engine while the old handler is still registered, and the stale one
        // answers on a dead messenger.
        binaryMessenger?.let { DeviceProbeHostApi.setUp(it, null) }
        binaryMessenger = null
    }
}
