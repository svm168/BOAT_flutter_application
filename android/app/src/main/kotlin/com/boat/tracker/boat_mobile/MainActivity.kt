package com.boat.tracker.boat_mobile

import android.bluetooth.BluetoothAdapter
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
    private val REQUEST_ENABLE_BT = 1001
    private var scanEventSink: EventChannel.EventSink? = null
    private var pendingEnableBtResult: MethodChannel.Result? = null

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
                    BleScanManager.clearScans()
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
                "requestEnableBluetooth" -> {
                    val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val adapter = bluetoothManager?.adapter
                    if (adapter == null) {
                        result.success(false)
                    } else if (adapter.isEnabled) {
                        result.success(true)
                    } else {
                        pendingEnableBtResult = result
                        val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                        try {
                            startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                        } catch (e: Exception) {
                            pendingEnableBtResult = null
                            result.error("BLUETOOTH_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val isEnabled = bluetoothManager?.adapter?.isEnabled == true
            pendingEnableBtResult?.success(isEnabled)
            pendingEnableBtResult = null
        }
    }

    override fun onDestroy() {
        BleScanManager.listener = null
        scanEventSink = null
        pendingEnableBtResult = null
        super.onDestroy()
    }
}
