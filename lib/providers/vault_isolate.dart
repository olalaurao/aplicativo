import 'dart:isolate';
import '../models/content_object.dart';


/// Data class that holds the results of parsing the vault in an isolate.
class ParsedVaultResult {
  final List<ContentObject> objects;
  final Map<String, Map<String, dynamic>> dailyMap;

  ParsedVaultResult({required this.objects, required this.dailyMap});
}

/// Entry point for the isolate. Receives a [SendPort] to communicate back the
/// [ParsedVaultResult]. The arguments list must contain the necessary data to
/// perform the parsing without needing to access non‑transferable objects.
///
/// For now this is a placeholder implementation that simply returns empty data.
/// The full implementation will mirror the logic currently inside
/// `AllObjectsNotifier.build()` but will run off the UI thread.
Future<void> _parseVaultIsolate(SendPort sendPort) async {
  // TODO: Receive arguments (e.g., vault path, settings) via a ReceivePort.
  // Perform the same batch file reading and parsing as in AllObjectsNotifier.
  // When done, send the result back:
  // sendPort.send(ParsedVaultResult(objects: parsedObjects, dailyMap: dailyDataMap));
  // Placeholder empty result for now.
  sendPort.send(ParsedVaultResult(objects: [], dailyMap: {}));
}

/// Helper that spawns the isolate and returns a [Future] of [ParsedVaultResult].
Future<ParsedVaultResult> parseVaultInIsolate() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_parseVaultIsolate, receivePort.sendPort);
  final result = await receivePort.first as ParsedVaultResult;
  return result;
}
