export 'data_integrity_json_parser_fallback.dart'
    if (dart.library.io) 'data_integrity_json_parser_io.dart'
    if (dart.library.html) 'data_integrity_json_parser_web.dart';
