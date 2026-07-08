import 'dart:io';

Future<void> main() async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  final uri = Uri.parse('https://vt.tiktok.com/zscwxklqx');
  final request = await client.getUrl(uri);
  request.followRedirects = false; // DON'T follow automatically
  request.headers.set('User-Agent', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1');
  final response = await request.close();
  
  print('Status: \${response.statusCode}');
  print('Location: \${response.headers.value('location')}');
}
