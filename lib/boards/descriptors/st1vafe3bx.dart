// Copyright (c) 2024-2026 protocentral
// SPDX-License-Identifier: MIT

import '../board_descriptor.dart';
import '../channel_spec.dart';
import '../decoders/st1vafe3bx_decoders.dart';
import '../packet_spec.dart';
import '../transport_profile.dart';

final BoardDescriptor st1vafe3bxDescriptor = BoardDescriptor(
  id: 'st1vafe3bx',
  displayName: 'ST1VAFE3BX ECG Breakout',
  manufacturer: 'ProtoCentral',
  transports: const TransportSupport(usb: true),
  usbProfile: const UsbProfile(
    baudRate: 57600,
  ),
  channels: const [
    ChannelSpec(
      id: 'ecg',
      label: 'ECG',
      sampleRateHz: 128,
      unit: SignalUnit.adc,
      kind: ChannelKind.ecg,
    ),
  ],
  packets: [
    PacketSpec(
      pktType: 2,
      label: 'ECG',
      expectedPayloadLength: 12,
      decode: decodeSt1vafe3bxPkt2,
    ),
  ],
  notes: 'STMicroelectronics ST1VAFE3BX single-lead vAFE + 3-axis accel '
      'breakout. OpenView v1 streams ECG at 128 Hz over USB from the Arduino '
      'OpenView examples (03.ECGOpenView, 05.SmartRecorder) at 57600 baud. '
      'Accel/MLC are on-chip but not in this packet. The USB VID/PID is the '
      'host MCU, not unique to this board — select it on the Connect tab.',
);
