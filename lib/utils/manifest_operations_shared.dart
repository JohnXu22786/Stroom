import 'file_record.dart';

String hashOf(dynamic r) => (r as Hashable).hash;
String storageNameOf(dynamic r) => (r as Storable).storagePath;
String folderOf(dynamic r) => (r as FileRecord).folder;

T copyName<T extends FileRecord>(T r, String name) =>
    (r as dynamic).copyWithName(name) as T;
T copyFolder<T extends FileRecord>(T r, String folder) =>
    (r as dynamic).copyWithFolder(folder) as T;
