package com.boat.tracker.boat_mobile

import java.util.concurrent.ConcurrentHashMap

data class BleScanRecord(
    val deviceName: String,
    val deviceAddress: String,
    val rssi: Int,
    val rawHex: String,
    val bikeId: String,
    val isBoat: Boolean,
    val timestamp: Long,
    var uploadStatus: String = "Detected",
    var lastUploadedAt: Long = 0L
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "deviceName" to deviceName,
            "deviceAddress" to deviceAddress,
            "rssi" to rssi,
            "rawHex" to rawHex,
            "bikeId" to bikeId,
            "isBoat" to isBoat,
            "timestamp" to timestamp,
            "uploadStatus" to uploadStatus,
            "lastUploadedAt" to lastUploadedAt
        )
    }
}

object BleScanManager {
    private val scanMap = ConcurrentHashMap<String, BleScanRecord>()
    var listener: ((BleScanRecord) -> Unit)? = null

    fun addOrUpdate(record: BleScanRecord) {
        val existing = scanMap[record.deviceAddress]
        val statusToKeep = if (record.uploadStatus == "Detected" && existing != null && existing.uploadStatus != "Detected") {
            existing.uploadStatus
        } else {
            record.uploadStatus
        }
        val uploadTimeToKeep = if (record.lastUploadedAt > 0) record.lastUploadedAt else (existing?.lastUploadedAt ?: 0L)

        val updated = record.copy(
            uploadStatus = statusToKeep,
            lastUploadedAt = uploadTimeToKeep
        )
        scanMap[record.deviceAddress] = updated
        listener?.invoke(updated)
    }

    fun updateStatus(addressOrBikeId: String, status: String, uploadedAt: Long = 0L) {
        for ((key, item) in scanMap) {
            if (key.equals(addressOrBikeId, ignoreCase = true) ||
                (item.bikeId.isNotEmpty() && item.bikeId.equals(addressOrBikeId, ignoreCase = true))) {
                item.uploadStatus = status
                if (uploadedAt > 0) item.lastUploadedAt = uploadedAt
                listener?.invoke(item)
            }
        }
    }

    fun getRecentScans(): List<Map<String, Any?>> {
        return scanMap.values
            .sortedByDescending { it.timestamp }
            .take(60)
            .map { it.toMap() }
    }

    fun clearScans() {
        scanMap.clear()
    }
}
