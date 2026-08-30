// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../../protocol/decoded_packet.dart';
import 'shared_codecs.dart';

/// ST1VAFE3BX ECG Breakout (USB) — pktType 2 — 128 Hz.
///
/// Matches the Arduino OpenView sketches in
/// `protocentral_st1vafe3bx_arduino`:
///   * `examples/03.ECGOpenView` — ECG in [0-3], same ECG duplicated in
///     [4-7] (the sketch calls that slot "bioz"), skip flag in [8].
///   * `examples/05.SmartRecorder` — ECG in [0-3], [4-11] zeroed.
///
/// The chip is a single-lead vAFE, not a BioZ AFE. OpenView v1 therefore
/// exposes only `ecg` and ignores bytes 4–11. Do not decode this payload as
/// MAX30001 (different baud, and MAX30001 treats [8-11] as HR/RR).
///
/// Payload layout (12 bytes):
///   [0-3]    ecg    int32 LE  (raw vAFE ADC count from `readVAFE_Raw()`)
///   [4-7]    unused int32 LE  (duplicate ECG in ex. 03; zeros in ex. 05)
///   [8]      unused uint8     (bioz skip in ex. 03; 0 in ex. 05)
///   [9-11]   reserved
DecodedPacket decodeSt1vafe3bxPkt2(Uint8List p) {
  if (p.length < 4) return const DecodedPacket(pktType: 2);

  final ecg = Codec.readInt32LE(p, 0).toDouble();
  return DecodedPacket(
    pktType: 2,
    channelSamples: {
      'ecg': [ecg],
    },
  );
}
