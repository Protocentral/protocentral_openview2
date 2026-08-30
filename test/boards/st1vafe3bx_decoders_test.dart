// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import 'dart:typed_data';

import 'package:OpenView/boards/decoders/st1vafe3bx_decoders.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _pkt({
  required int ecg,
  int slot4to7 = 0,
  int byte8 = 0,
}) {
  final p = Uint8List(12);
  final data = ByteData.sublistView(p);
  data.setInt32(0, ecg, Endian.little);
  data.setInt32(4, slot4to7, Endian.little);
  p[8] = byte8;
  return p;
}

void main() {
  test('Example 03 payload: ECG duplicated in BioZ slot, only ecg emitted', () {
    const sample = 0x00123456;
    final decoded = decodeSt1vafe3bxPkt2(_pkt(
      ecg: sample,
      slot4to7: sample,
      byte8: 0x00,
    ));

    expect(decoded.pktType, 2);
    expect(decoded.channelSamples.keys, ['ecg']);
    expect(decoded.channelSamples['ecg'], [sample.toDouble()]);
    expect(decoded.events, isEmpty);
    expect(decoded.matrixFrames, isEmpty);
  });

  test('Example 05 payload: BioZ slot zeroed, still only ecg', () {
    const sample = 42;
    final decoded = decodeSt1vafe3bxPkt2(_pkt(ecg: sample));

    expect(decoded.channelSamples.keys, ['ecg']);
    expect(decoded.channelSamples['ecg'], [42.0]);
    expect(decoded.events, isEmpty);
  });

  test('Short payload is empty (router will drop it)', () {
    final decoded = decodeSt1vafe3bxPkt2(Uint8List.fromList([0x01, 0x02, 0x03]));
    expect(decoded.isEmpty, isTrue);
    expect(decoded.pktType, 2);
  });

  test('Negative / sign-extended int32 ECG is preserved', () {
    const sample = -123456;
    final decoded = decodeSt1vafe3bxPkt2(_pkt(ecg: sample, slot4to7: sample));
    expect(decoded.channelSamples['ecg'], [sample.toDouble()]);
  });
}
