import 'board_handler.dart';
import 'healthypi_usb_handler.dart';
//import 'healthypi_eeg_handler.dart';
//import 'ads1292r_handler.dart';
// Import other handlers...

class BoardRegistry {
  static final Map<String, BoardHandler> _handlers = {
    'Healthypi (USB)': HealthyPiUSBHandler(),
    //'Healthypi EEG': HealthyPiEEGHandler(),
    //'ADS1292R Breakout/Shield (USB)': ADS1292RHandler(),
    // Add other boards here...
  };
  
  static BoardHandler? getHandler(String boardName) {
    return _handlers[boardName];
  }
  
  static void registerHandler(String boardName, BoardHandler handler) {
    _handlers[boardName] = handler;
  }
  
  static List<String> getSupportedBoards() {
    return _handlers.keys.toList();
  }
}