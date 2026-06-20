import 'dart:io';

void main() {
  final file = File(r'c:\Users\admin\bestie\bestie\lib\features\chat\presentation\screens\chat_detail_screen.dart');
  var lines = file.readAsLinesSync();
  
  if (lines[554].contains('emoji = isBestie')) {
    lines[554] = "                          final emoji = isBestie ? '🔥' : (temp >= 50 ? '🌶️' : '❄️');";
  }
  if (lines[558].contains('Text')) {
    lines[558] = "                              Text('\$emoji \${temp.toInt()}°C', ";
  }
  
  file.writeAsStringSync(lines.join('\r\n'));
}
