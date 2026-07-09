import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final url = 'https://www.instagram.com/p/C-h9rMuv-5j/';
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)');
    final response = await request.close();
    
    if (response.statusCode == 200) {
       final html = await response.transform(utf8.decoder).join();
       final ogMatch = RegExp(r'<meta property="og:image" content="([^"]+)"').firstMatch(html);
       if (ogMatch != null) {
         print('Found og:image: ${ogMatch.group(1)}');
       } else {
         print('No og:image found');
       }
    } else {
       print('Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
