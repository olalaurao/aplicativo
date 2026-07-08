import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  final uri = Uri.parse('https://vt.tiktok.com/zscwxklqx');
  final request = await client.getUrl(uri);
  // Default desktop UA
  request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
  final response = await request.close();
  final finalUrl = response.redirects.isNotEmpty ? response.redirects.last.location.toString() : request.uri.toString();
  print('Final URL: ' + finalUrl);
}
