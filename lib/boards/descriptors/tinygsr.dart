// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import '../board_descriptor.dart';
import '../channel_spec.dart';
import '../decoders/tinygsr_decoders.dart';
import '../packet_spec.dart';
import '../transport_profile.dart';

final BoardDescriptor tinyGsrDescriptor = BoardDescriptor(
  id: 'tinygsr',
  displayName: 'tinyGSR Breakout',
  manufacturer: 'ProtoCentral',
  transports: const TransportSupport(usb: true),
  usbProfile: const UsbProfile(
    baudRate: 57600,
  ),
  channels: const [
    ChannelSpec(
      id: 'gsr',
      label: 'GSR/EDA',
      sampleRateHz: 10,
      unit: SignalUnit.microSiemens,
      kind: ChannelKind.gsr,
      // Typical tonic skin conductance level sits around 2-20 uS; the front
      // end saturates near 104 uS.
      displayMin: 0,
      displayMax: 25,
    ),
  ],
  packets: [
    PacketSpec(
      pktType: 3,
      label: 'Skin conductance',
      expectedPayloadLength: 8,
      decode: decodeTinyGsrPkt3,
    ),
  ],
  notes: 'ProtoCentral tinyGSR Galvanic Skin Response (GSR) / '
      'Electrodermal Activity (EDA) breakout. Qwiic / STEMMA QT compatible. '
      'A 0.5 V constant-voltage transimpedance front end and a 12-bit ADC give '
      'absolute skin conductance, streamed at ~10 Hz as integer nanosiemens '
      'and plotted here in microsiemens. Firmware older than the pktType 3 '
      'format streamed raw ADC counts on pktType 2; those show up as an '
      'unknown packet type in the Console rather than a mis-scaled trace.',
);
