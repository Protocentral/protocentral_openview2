
/************** Packet Validation  **********************/
const int CESState_Init = 0;
const int CESState_SOF1_Found = 1;
const int CESState_SOF2_Found = 2;
const int CESState_PktLen_Found = 3;

/*CES CMD IF Packet Format*/
const int CES_CMDIF_PKT_START_1 = 0x0A;
const int CES_CMDIF_PKT_START_2 = 0xFA;
const int CES_CMDIF_PKT_STOP = 0x0B;

/*CES CMD IF Packet Indices*/
const int CES_CMDIF_IND_LEN = 2;
const int CES_CMDIF_IND_LEN_MSB = 3;
const int CES_CMDIF_IND_PKTTYPE = 4;
int CES_CMDIF_PKT_OVERHEAD = 5;

/************** Packet Related Variables **********************/
int pc_rx_state = 0; // To check the state of the packet
int CES_Pkt_Len = 0; // To store the Packet Length Deatils
int CES_Pkt_Pos_Counter = 0;
int CES_Data_Counter = 0; // Packet and data counter
int CES_ECG_RESP_Data_Counter = 0; // Packet and data counter
int CES_PPG_Data_Counter = 0; // Packet and data counter
int CES_Pkt_PktType = 0; // To store the Packet Type
int computed_val1 = 0;
int computed_val2 = 0;

var CES_Pkt_Data_Counter = new List.filled(1000, 0, growable: false);
var CES_Pkt_ECG_RESP_Data_Counter = new List.filled(1000, 0, growable: false);
var CES_Pkt_PPG_Data_Counter = new List.filled(1000, 0, growable: false);

var ces_pkt_ch1_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch2_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch3_buffer = new List.filled(4, 0, growable: false);

var ces_pkt_ch4_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch5_buffer = new List.filled(4, 0, growable: false);

var ces_pkt_eeg1_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg2_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg3_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg4_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg5_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg6_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg7_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_eeg8_buffer = new List.filled(4, 0, growable: false);


var listOFUSBBoards = {
  'Healthypi (USB)',
  'Healthypi 6 (USB)',
  'Sensything Ox (USB)',
  //'Healthypi EEG',
  'ADS1292R Breakout/Shield (USB)',
  'ADS1293 Breakout/Shield (USB)',
  'AFE4490 Breakout/Shield (USB)',
  'MAX86150 Breakout (USB)',
  'Pulse Express (USB)',
  'tinyGSR Breakout (USB)',
  'MAX30003 ECG Breakout (USB)',
  'MAX30001 ECG & BioZ Breakout (USB)'
};

var listOFBLEBoards = {
  'Healthypi (BLE)',
  'Sensything Ox (BLE)'
};

typedef LogHeader = ({
  int logFileID,
  int sessionLength,
  int fileNo,
  int tmSec,
  int tmMin,
  int tmHour,
  int tmMday,
  int tmMon,
  int tmYear
});