import 'dart:io';

void main() async {
  try {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('https://vm.tiktok.com/ZMh5sH4Wk/'));
    request.followRedirects = false;
    request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36');
    final response = await request.close();
    print('Status: ${response.statusCode}');
    print('Location: ${response.headers.value('location')}');
  } catch (e) {
    print('Error: $e');
  }
}
