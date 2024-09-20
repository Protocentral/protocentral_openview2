
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
int CES_Pkt_PktType = 0; // To store the Packet Type
int computed_val1 = 0;
int computed_val2 = 0;

var CES_Pkt_Data_Counter = new List.filled(1000, 0, growable: false);
var ces_pkt_ch1_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch2_buffer = new List.filled(4, 0, growable: false);
var ces_pkt_ch3_buffer = new List.filled(4, 0, growable: false);


var listOFBoards = {
  'Healthypi',
  'ADS1292R Breakout/Shield',
  'ADS1293 Breakout/Shield',
  'AFE4490 Breakout/Shield',
  'MAX86150 Breakout',
  'Pulse Express',
  'tinyGSR Breakout',
  'MAX30003 ECG Breakout',
  'MAX30001 ECG & BioZ Breakout'
};

typedef LogHeader = ({
  int logFileID,
  int sessionLength,
  int tmSec,
  int tmMin,
  int tmHour,
  int tmMday,
  int tmMon,
  int tmYear
});