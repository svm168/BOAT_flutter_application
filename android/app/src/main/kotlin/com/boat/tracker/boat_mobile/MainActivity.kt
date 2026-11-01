package com.boat.tracker.boat_mobile

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.boat.tracker/beacon_scanner"
    private val EVENT_CHANNEL = "com.boat.tracker/ble_scan_events"
    private var scanEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for real-time BLE scan streaming
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    scanEventSink = events
                    BleScanManager.listener = { record ->
                        runOnUiThread {
                            scanEventSink?.success(record.toMap())
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    BleScanManager.listener = null
                    scanEventSink = null
                }
            }
        )

        // MethodChannel for control and query
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScanning" -> {
                    val serverUrl = call.argument<String>("serverUrl") ?: BeaconScanningService.serverUrl
                    val beaconUuid = call.argument<String>("beaconUuid") ?: BeaconScanningService.targetUuid
                    BeaconScanningService.serverUrl = serverUrl
                    BeaconScanningService.targetUuid = beaconUuid

                    val intent = Intent(this, BeaconScanningService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopScanning" -> {
                    val intent = Intent(this, BeaconScanningService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isScanning" -> {
                    result.success(BeaconScanningService.isRunning)
                }
                "getRecentScans" -> {
                    result.success(BleScanManager.getRecentScans())
                }
                "clearScans" -> {
                    BleScanManager.clearScans()
                    result.success(true)
                }
                "isBluetoothEnabled" -> {
                    val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val isEnabled = bluetoothManager?.adapter?.isEnabled == true
                    result.success(isEnabled)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        BleScanManager.listener = null
        scanEventSink = null
        super.onDestroy()
    }
}
