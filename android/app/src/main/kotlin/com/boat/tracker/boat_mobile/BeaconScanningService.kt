package com.boat.tracker.boat_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.ConcurrentHashMap

class BeaconScanningService : Service() {
    private val TAG = "BOAT_BLE_SERVICE"
    private val httpClient = OkHttpClient()
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    // 5-Minute Client-Side Cooldown Cache: Key is bikeId, Value is System timestamp (ms)
    private val cooldownCache = ConcurrentHashMap<String, Long>()
    private val COOLDOWN_MS = 5 * 60 * 1000L // 5 minutes

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bleScanner: BluetoothLeScanner? = null
    private var isScanningActive = false

    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                if (state == BluetoothAdapter.STATE_ON) {
                    Log.i(TAG, "Bluetooth turned ON, starting BLE scan...")
                    startBleScan()
                } else if (state == BluetoothAdapter.STATE_OFF) {
                    Log.i(TAG, "Bluetooth turned OFF, stopping BLE scan...")
                    stopBleScan()
                }
            }
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.let { handleScanResult(it) }
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>?) {
            results?.forEach { handleScanResult(it) }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "BLE Scan failed with errorCode: $errorCode")
        }
    }

    companion object {
        var serverUrl = "http://10.0.2.2:3000/api/location"
        var targetUuid = "f7826da6-4fa2-4e98-8024-bc5b71e0893e"
        var isRunning = false
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        startForegroundNotification()

        val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
        registerReceiver(bluetoothReceiver, filter)

        startBleScan()
    }

    private fun startForegroundNotification() {
        val channelId = "boat_mesh_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "BOAT Campus Mesh Scanner",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Passively detecting campus bicycle beacons in the background"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("BOAT Mesh Scanner Active")
            .setContentText("Passively relaying campus bicycle locations")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var serviceType = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                serviceType = serviceType or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            }
            startForeground(101, notification, serviceType)
        } else {
            startForeground(101, notification)
        }
    }

    private fun startBleScan() {
        if (isScanningActive) return
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            bluetoothAdapter = bluetoothManager?.adapter
            if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
                Log.w(TAG, "Bluetooth is disabled or not available on this device")
                return
            }

            bleScanner = bluetoothAdapter?.bluetoothLeScanner
            if (bleScanner == null) {
                Log.w(TAG, "BluetoothLeScanner instance could not be obtained")
                return
            }

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .setReportDelay(0)
                .build()

            bleScanner?.startScan(null, settings, scanCallback)
            isScanningActive = true
            Log.i(TAG, "Native BLE Scanner started successfully (LOW_LATENCY)")
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException starting BLE scan: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting BLE scan: ${e.message}", e)
        }
    }

    private fun stopBleScan() {
        if (!isScanningActive) return
        try {
            bleScanner?.stopScan(scanCallback)
            Log.i(TAG, "Native BLE Scanner stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping BLE scan: ${e.message}")
        } finally {
            isScanningActive = false
        }
    }

    private fun handleScanResult(result: ScanResult) {
        val record = result.scanRecord
        val device = result.device

        var deviceName = record?.deviceName ?: ""
        if (deviceName.isEmpty()) {
            try {
                deviceName = device.name ?: ""
            } catch (_: SecurityException) {}
        }
        val address = device.address ?: "00:00:00:00:00:00"
        val rssi = result.rssi

        // Check if device is BOAT
        val isBoat = deviceName.equals("BOAT", ignoreCase = true) || deviceName.contains("BOAT", ignoreCase = true)

        // Parse Manufacturer Data
        val (rawHex, bikeId) = parseManufacturerData(record)

        val recordItem = BleScanRecord(
            deviceName = if (deviceName.isNotEmpty()) deviceName else (if (isBoat) "BOAT" else "BLE Device"),
            deviceAddress = address,
            rssi = rssi,
            rawHex = rawHex,
            bikeId = bikeId,
            isBoat = isBoat,
            timestamp = System.currentTimeMillis()
        )

        // Update in-memory scan manager for diagnostics UI
        BleScanManager.addOrUpdate(recordItem)

        // Upload ONLY contents of "BOAT" devices
        if (isBoat && bikeId.isNotEmpty()) {
            val now = System.currentTimeMillis()
            val lastSent = cooldownCache[bikeId] ?: 0L

            if (now - lastSent >= COOLDOWN_MS) {
                cooldownCache[bikeId] = now
                Log.d(TAG, "New BOAT bike detected: ID=$bikeId (Hex=$rawHex, RSSI=$rssi). Acquiring GPS fix...")
                BleScanManager.updateStatus(address, "Acquiring GPS fix...")
                dispatchFix(bikeId, rawHex, address)
            } else {
                val remSeconds = ((COOLDOWN_MS - (now - lastSent)) / 1000).coerceAtLeast(1)
                BleScanManager.updateStatus(address, "Cooldown active (${remSeconds}s remaining)")
            }
        }
    }

    /**
     * Extracts the raw hex string and decodes the ASCII bike ID from manufacturer data.
     * In the ESP32 code:
     * payload[0] = COMPANY_ID_LSB (0xFF)
     * payload[1] = COMPANY_ID_MSB (0xFF)
     * payload[2..] = ASCII characters of BIKE_ID (e.g. "FR6C7VTH")
     */
    private fun parseManufacturerData(record: ScanRecord?): Pair<String, String> {
        if (record == null) return Pair("", "")

        var mfgBytes: ByteArray? = null
        val sparse = record.manufacturerSpecificData

        if (sparse != null && sparse.size() > 0) {
            // Check company ID 0xFFFF (65535 or -1 as signed 16-bit)
            if (sparse.indexOfKey(0xFFFF) >= 0) {
                mfgBytes = sparse.get(0xFFFF)
            } else if (sparse.indexOfKey(-1) >= 0) {
                mfgBytes = sparse.get(-1)
            } else {
                // First available manufacturer data
                mfgBytes = sparse.valueAt(0)
            }
        }

        // Fallback: parse raw advertisement bytes manually
        if (mfgBytes == null && record.bytes != null) {
            val bytes = record.bytes!!
            var i = 0
            while (i < bytes.size) {
                val len = bytes[i].toInt() and 0xFF
                if (len == 0) break
                if (i + len >= bytes.size) break
                val type = bytes[i + 1].toInt() and 0xFF
                if (type == 0xFF && len >= 3) {
                    // Manufacturer Specific Data: Company ID is 2 bytes at i+2, i+3; payload at i+4
                    mfgBytes = bytes.copyOfRange(i + 2, i + 1 + len)
                    break
                }
                i += 1 + len
            }
        }

        if (mfgBytes == null || mfgBytes.isEmpty()) {
            return Pair("", "")
        }

        // Build raw hex representation
        val hexSb = StringBuilder()
        for (b in mfgBytes) {
            hexSb.append(String.format("%02X", b))
        }
        var rawHex = hexSb.toString()

        // Check if bytes start with 0xFF 0xFF (company ID included)
        var offset = 0
        if (mfgBytes.size >= 2 && (mfgBytes[0].toInt() and 0xFF == 0xFF) && (mfgBytes[1].toInt() and 0xFF == 0xFF)) {
            offset = 2
        } else if (!rawHex.startsWith("FFFF")) {
            // For display consistency, show full manufacturer packet hex
            rawHex = "FFFF$rawHex"
        }

        // Convert remaining bytes to normal characters (ASCII numbers/letters)
        val idSb = StringBuilder()
        for (j in offset until mfgBytes.size) {
            val c = (mfgBytes[j].toInt() and 0xFF)
            if (c in 32..126) { // Printable ASCII
                idSb.append(c.toChar())
            } else if (c == 0) {
                break
            }
        }

        val decodedId = idSb.toString().trim()
        return Pair(rawHex, decodedId)
    }

    private fun dispatchFix(bikeId: String, rawHex: String, deviceAddress: String) {
        val fusedClient = LocationServices.getFusedLocationProviderClient(this)
        try {
            fusedClient.lastLocation.addOnSuccessListener { location ->
                if (location != null) {
                    sendLocationReport(bikeId, rawHex, deviceAddress, location.latitude, location.longitude, location.accuracy)
                } else {
                    // Fallback to active current location fix
                    try {
                        val cts = CancellationTokenSource()
                        fusedClient.getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, cts.token)
                            .addOnSuccessListener { currLocation ->
                                if (currLocation != null) {
                                    sendLocationReport(bikeId, rawHex, deviceAddress, currLocation.latitude, currLocation.longitude, currLocation.accuracy)
                                } else {
                                    Log.w(TAG, "Current location is null, using campus fallback coordinates")
                                    // IIT Roorkee campus default fallback
                                    sendLocationReport(bikeId, rawHex, deviceAddress, 29.86512, 77.89645, 10.0f)
                                }
                            }
                            .addOnFailureListener { e ->
                                Log.e(TAG, "Failed to get current location: ${e.message}")
                                BleScanManager.updateStatus(deviceAddress, "GPS fix failed: ${e.message}")
                            }
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception requesting current location: ${e.message}")
                        BleScanManager.updateStatus(deviceAddress, "GPS error: ${e.message}")
                    }
                }
            }.addOnFailureListener { e ->
                Log.e(TAG, "Failed to get last location: ${e.message}")
                BleScanManager.updateStatus(deviceAddress, "GPS error: ${e.message}")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission missing: ${e.message}")
            BleScanManager.updateStatus(deviceAddress, "Location permission missing")
        }
    }

    private fun sendLocationReport(
        bikeId: String,
        rawHex: String,
        deviceAddress: String,
        lat: Double,
        lng: Double,
        accuracy: Float
    ) {
        val endpoint = if (serverUrl.endsWith("/api/location")) serverUrl else "$serverUrl/api/location"

        val payload = JSONObject().apply {
            put("publicId", bikeId)
            put("tagId", bikeId)
            put("lat", lat)
            put("lng", lng)
            put("accuracyM", accuracy.toDouble())
            put("source", "ble")
            put("note", "BLE scan: $bikeId (device: BOAT, hex: $rawHex)")
        }

        Log.i(TAG, "Dispatching location sighting for bike $bikeId to $endpoint: $payload")
        BleScanManager.updateStatus(deviceAddress, "Uploading to server...")

        val request = Request.Builder()
            .url(endpoint)
            .post(payload.toString().toRequestBody(JSON_MEDIA_TYPE))
            .build()

        httpClient.newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                val errMsg = "Upload failed: ${e.message}"
                Log.e(TAG, errMsg)
                BleScanManager.updateStatus(deviceAddress, errMsg)
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                val code = response.code
                val respBody = response.body?.string() ?: ""
                response.close()

                if (response.isSuccessful) {
                    val successMsg = "Uploaded (HTTP $code OK)"
                    Log.i(TAG, "Check-in successful! Code: $code - $respBody")
                    BleScanManager.updateStatus(deviceAddress, successMsg, System.currentTimeMillis())
                } else {
                    val failMsg = "Rejected (HTTP $code)"
                    Log.w(TAG, "Server rejected location fix: Code $code - $respBody")
                    BleScanManager.updateStatus(deviceAddress, failMsg)
                }
            }
        })
    }

    override fun onDestroy() {
        isRunning = false
        try {
            unregisterReceiver(bluetoothReceiver)
        } catch (_: Exception) {}
        stopBleScan()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
