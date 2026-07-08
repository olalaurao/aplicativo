import 'dart:io';

Future<void> main() async {
  final url = 'https://vt.tiktok.com/zscw5vrpq?';
  print('Testing: $url');
  
  final client = HttpClient();
  var currentUrl = url;
  
  try {
    for (int i = 0; i < 10; i++) {
      print('Hop $i: $currentUrl');
      final request = await client.getUrl(Uri.parse(currentUrl));
      request.followRedirects = false;
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
      
      final response = await request.close();
      print('Status: ${response.statusCode}');
      
      if (response.isRedirect) {
        final location = response.headers.value('location');
        print('Location: $location');
        if (location != null) {
          if (location.startsWith('/')) {
             final uri = Uri.parse(currentUrl);
             currentUrl = '${uri.scheme}://${uri.host}$location';
          } else {
             currentUrl = location;
          }
          continue;
        }
      }
      break;
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
