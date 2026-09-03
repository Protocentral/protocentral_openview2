// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import '../../protocol/decoded_packet.dart';
import 'shared_codecs.dart';

/// tinyGSR Breakout (USB) — pktType 3 — ~10 Hz absolute skin conductance.
///
/// tinyGSR measures electrodermal activity (EDA), the change in skin
/// conductance that tracks sympathetic arousal.  The v2 front end holds a
/// constant 0.5 V across the electrodes and reads the resulting current
/// through a 39.2 kΩ transimpedance stage with a 12-bit differential ADC, so
/// the firmware can report conductance in absolute units rather than an
/// uncalibrated count.
///
/// The firmware sends **integer nanosiemens** (µS × 1000).  One ADC count is
/// ≈ 50.9 nS, so the integer wire format is about 20× finer than the ADC
/// itself resolves — nothing is lost, and the same slot still carries the
/// 16-bit "Standard" front end.  Any one-point Rcal calibration stored on the
/// board is already folded in by the time it reaches us.
///
/// The resistance slot is reserved and always 0: EDA skin resistance spans
/// tens of kilohms to several megohms, which overflows an int16 in ohms, and
/// it is exactly 1e6 / G anyway.
///
/// Payload layout (8 bytes):
///   [0-3]   gsr      int32 LE  (skin conductance, nanosiemens)
///   [4-5]   —        int16 LE  (reserved, 0)
///   [6-7]   0x0000   reserved

/// Nanosiemens on the wire → microsiemens for display and recording.
const double _nsPerUs = 1000.0;

DecodedPacket decodeTinyGsrPkt3(Uint8List p) {
  final microSiemens = Codec.readInt32LE(p, 0) / _nsPerUs;

  return DecodedPacket(
    pktType: 3,
    channelSamples: {
      'gsr': [microSiemens],
    },
  );
}
