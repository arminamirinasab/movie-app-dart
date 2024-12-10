import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import './services/db_services.dart';

void main() async {
  final dbService = DBService();
  final router = Router();

  // shows all Movies
  router.get('/movies', (Request request) async {
    final movies = await dbService.getAllMovies();

    final moviesWithDetails = movies.map((movie) {
      movie['poster_url'] =
          'https://picsum.photos/200/300?random=${movie['id']}';
      movie['release_date'] =
          (movie['release_date'] as DateTime?)?.toIso8601String();
      movie['created_at'] =
          (movie['created_at'] as DateTime?)?.toIso8601String();
      return movie;
    }).toList();

    return Response.ok(
      jsonEncode(moviesWithDetails),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // add new movie
  router.post('/movies', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);
    await dbService.addMovie(
      data['title'],
      data['description'],
      data['director'],
      data['release_year'],
      data['genre'],
    );
    return Response.ok('Movie added successfully!');
  });

  // Path to save files
  final uploadDirectory = Directory('uploads');
  if (!uploadDirectory.existsSync()) {
    uploadDirectory.createSync();
  }

  // upload file poster
  // router.post('/upload', (Request request) async {
  //   try {
  //     final contentType = request.headers['content-type'];
  //     if (contentType == null ||
  //         !contentType.startsWith('multipart/form-data')) {
  //       return Response.badRequest(body: 'Invalid content-type');
  //     }

  //     final boundary = contentType.split('boundary=')[1];
  //     if (boundary.isEmpty) {
  //       return Response.badRequest(body: 'Missing boundary in content-type');
  //     }

  //     String? filePath;
  //     filePath = "E:\\";
  //     // for (final part in parts) {
  //     //   if (part['filename'] != null && part['content'] != null) {
  //     //     filePath = '${uploadDirectory.path}/${part['filename']}';
  //     //     final file = File(filePath);
  //     //     await file.writeAsBytes(part['content']! as List<int>);
  //     //   }
  //     // }

  //     return Response.ok(
  //       jsonEncode({'filePath': filePath}),
  //       headers: {'Content-Type': 'application/json'},
  //     );
  //   } catch (e) {
  //     return Response.internalServerError(
  //       body: jsonEncode({'error': e.toString()}),
  //       headers: {'Content-Type': 'application/json'},
  //     );
  //   }
  // });


  // remove movie
  router.delete('/movies/<id|[0-9]+>', (Request request, String id) async {
    await dbService.deleteMovie(int.parse(id));
    return Response.ok('Movie deleted successfully!');
  });

  router.get('/movie/<id|[0-9]+>', (Request request, String id) async {
    try {
      final movie = await dbService.getMovieById(int.parse(id));
      if (movie == null) {
        return Response.notFound(jsonEncode({'error': 'Movie not found'}));
      }

      if (movie['release_year'] is DateTime) {
        movie['release_year'] =
            (movie['release_year'] as DateTime).toIso8601String();
      }
      if (movie['created_at'] is DateTime) {
        movie['created_at'] =
            (movie['created_at'] as DateTime).toIso8601String();
      }

      movie['poster_url'] = 'https://picsum.photos/200/300?random=$id';

      return Response.ok(
        jsonEncode(movie),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });
  // static server for showing web files
  final staticHandler =
      createStaticHandler('web', defaultDocument: 'index.html');
  final handler = Cascade().add(staticHandler).add(router.call).handler;

  // start server
  final server = await io.serve(handler, 'localhost', 8080);
  print('Server running at http://${server.address.host}:${server.port}');
}