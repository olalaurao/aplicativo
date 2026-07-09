import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final url = 'https://www.instagram.com/p/C-h9rMuv-5j/embed/captioned/';
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    final response = await request.close();
    
    if (response.statusCode == 200) {
       final html = await response.transform(utf8.decoder).join();
       print(html.substring(0, 1000)); // print first 1000 chars to see what it looks like
       File('ig_embed.html').writeAsStringSync(html);
       print('Saved to ig_embed.html');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
