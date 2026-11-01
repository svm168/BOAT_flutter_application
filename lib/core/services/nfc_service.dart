import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcService {
  static Future<bool> isAvailable() async {
    try {
      final availability = await NfcManager.instance.checkAvailability();
      return availability == NfcAvailability.enabled;
    } catch (e) {
      return false;
    }
  }

  static Future<void> startScan({
    required Function(String publicId, String rawData) onTagScanned,
    required Function(String error) onError,
  }) async {
    final available = await isAvailable();
    if (!available) {
      onError('NFC is not available or disabled on this device.');
      return;
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = NdefAndroid.from(tag);
            String rawText = '';

            if (ndef != null && ndef.cachedNdefMessage != null) {
              for (final record in ndef.cachedNdefMessage!.records) {
                final payload = record.payload;
                if (payload.isNotEmpty) {
                  final decoded = utf8.decode(payload, allowMalformed: true);
                  rawText += '$decoded ';
                }
              }
            }

            // Extract publicId from URL like /bike/ab3k9mpq or ab3k9mpq
            final bikeRegex = RegExp(r'/bike/([a-zA-Z0-9_-]+)');
            final match = bikeRegex.firstMatch(rawText);

            String publicId = '';
            if (match != null && match.groupCount >= 1) {
              publicId = match.group(1)!;
            } else {
              // Fallback: check if raw text contains an 8-char alphanumeric string
              final fallbackRegex = RegExp(r'\b[a-zA-Z0-9]{8}\b');
              final fallbackMatch = fallbackRegex.firstMatch(rawText);
              if (fallbackMatch != null) {
                publicId = fallbackMatch.group(0)!;
              }
            }

            await NfcManager.instance.stopSession();
            onTagScanned(publicId, rawText.trim());
          } catch (e) {
            await NfcManager.instance.stopSession();
            onError('Error processing NFC tag: $e');
          }
        },
      );
    } catch (e) {
      onError('Failed to start NFC session: $e');
    }
  }

  static Future<void> stopScan() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error stopping NFC session: $e');
    }
  }

  static Future<bool> writeBikeUrl({
    required String bikeUrl,
    required Function(String status) onStatus,
  }) async {
    final available = await isAvailable();
    if (!available) {
      onStatus('NFC is not supported or disabled on this device.');
      return false;
    }

    bool success = false;
    try {
      onStatus('Hold your phone near an NFC tag (e.g. NTAG215)...');
      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        onDiscovered: (NfcTag tag) async {
          final ndef = NdefAndroid.from(tag);
          if (ndef == null) {
            onStatus('Tag is not NDEF formatted or not supported.');
            await NfcManager.instance.stopSession();
            return;
          }

          if (!ndef.isWritable) {
            onStatus('Tag is read-only and cannot be written to.');
            await NfcManager.instance.stopSession();
            return;
          }

          try {
            // WellKnown URI record ('U')
            // Payload prefix 0x00 means raw URI string
            final uriBytes = utf8.encode(bikeUrl);
            final payload = Uint8List(uriBytes.length + 1);
            payload[0] = 0x00;
            payload.setRange(1, payload.length, uriBytes);

            final uriRecord = NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList([0x55]), // 'U'
              identifier: Uint8List(0),
              payload: payload,
            );

            final message = NdefMessage(records: [uriRecord]);
            await ndef.writeNdefMessage(message);
            success = true;
            onStatus('Successfully programmed tag with $bikeUrl!');
            await NfcManager.instance.stopSession();
          } catch (e) {
            onStatus('Failed to write tag: $e');
            await NfcManager.instance.stopSession();
          }
        },
      );
    } catch (e) {
      onStatus('Error writing NFC tag: $e');
    }
    return success;
  }
}
