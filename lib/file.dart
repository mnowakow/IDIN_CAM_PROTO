import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CustomFile {
  final String username;
  Directory directory = Directory('');
  CustomFile(this.username);

  void writeData(int objectIndex, String svg, String localOffset, String moveOffset, String bBox, double scale) async {
    File file = await _getLocalFile(objectIndex);

    String contents = '$svg BREAK $localOffset BREAK $moveOffset BREAK $bBox BREAK $scale';

    file.writeAsString(contents);
  }

  writeTemplateData(String svg, int numTemplates) async{
    File file = File('${directory.path}/templates/$numTemplates.svg');

    if(!await file.exists()) {
      file.create(recursive: true, exclusive: false);
    }

    file.writeAsString(svg);
  }

  Future<int> numTemplates() async{
    Directory dir = Directory('${directory.path}/templates/');
    await dir.create(recursive: true);

    List<FileSystemEntity> fileList = await dir.list().toList();
    int fileCount = fileList.whereType<File>().length;

    return fileCount;
  }

  Future<String> readTemplateData(int i) async{
    File file = File('${directory.path}/templates/$i.txt');

    return await file.readAsString();
  }

  void writeMoveOffset(int objectIndex, String moveOffset) async{
    List data = await returnFileAsList(directory.path, objectIndex);

    String contents = '${data[0]} BREAK ${data[1]} BREAK $moveOffset BREAK ${data[3]} BREAK ${data[4]}';
    File('${directory.path}/$objectIndex.txt').writeAsString(contents);
  }

  void writeScale(int objectIndex, String scale) async{
    List data = await returnFileAsList(directory.path, objectIndex);

    String contents = '${data[0]} BREAK ${data[1]} BREAK ${data[2]} BREAK ${data[3]} BREAK $scale';
    File('${directory.path}/$objectIndex.txt').writeAsString(contents);
  }

  Future<List> readData(String user) async{
    Directory dir = await _createDirectory(user);
    if(user == username) directory = dir;
    List<FileSystemEntity> fileList = await dir.list().toList();
    int fileCount = fileList.whereType<File>().length;
    List data = [];

    for(int i = 0; i < fileCount; i++){
      data.add(await returnFileAsList(dir.path, i));
    }

    return data;
  }

  Future<List> readUserListData(List<String> userList) async{
    List userListData = [];
    for(String user in userList){
      userListData.add(await readData(user));
    }
    return userListData;
  }

  Future<List> returnFileAsList(String dirPath, int objectIndex) async {
    File file = File('$dirPath$objectIndex.txt');
    String fileContents = await file.readAsString();
    return fileContents.split(' BREAK ');
  }

  void deleteFile(int objectIndex) async{
    String directoryPath = directory.path;
    await File('$directoryPath$objectIndex.txt').delete();

    List<FileSystemEntity> fileList = await directory.list().toList();
    int fileCount = fileList.whereType<File>().length;
    File currFile = File('');
    
    for(int i = objectIndex + 1; i < fileCount + 1; i++){
      currFile = File('$directoryPath$i.txt');
      await currFile.rename('$directoryPath${i - 1}.txt');
    }
  }

  Future<Directory> _createDirectory(String user) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    Directory newDirectory = Directory('$appDocPath/$user/');

    Directory newFolder = await newDirectory.create(recursive: true);
    return newFolder;
  }

  Future<File> _getLocalFile(int objectIndex) async{
    String parentPath = directory.path;
    File file = File('$parentPath/$objectIndex.txt');

    if(!await file.exists()) {
      file.create(recursive: true, exclusive: false);
    }

    return file;
  }

  Future<List<String>> usernameList() async{
    Directory appDocDir = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> list = await appDocDir.list().toList();
    List<String> usernames = [];
    int pathLength = appDocDir.path.length + 1;

    for(int i = 0; i < list.length; i++){
      usernames.add(list.elementAt(i).path.substring(pathLength));
    }

    return usernames;
  }
}