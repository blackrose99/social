// test/check_users_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mongo_dart/mongo_dart.dart';

void main() {
  test('Probar consulta de participantes', () async {
    final user = "lmcastano";
    final rawPassword = r"1q2w3e4r5T*/*";
    final encodedPassword = Uri.encodeComponent(rawPassword);
    final host = "cluster0.zckl11f.mongodb.net";
    final dbName = "stealth_social";

    final uri = "mongodb+srv://$user:$encodedPassword@$host/$dbName?retryWrites=true&w=majority";

    final db = await Db.create(uri);
    await db.open();

    final convCol = db.collection('conversations');

    final test1 = await convCol.find(where.eq('participants', 'mannu')).toList();
    print("Test 1 (where.eq('participants', 'mannu')): ${test1.length} resultados");

    final test2 = await convCol.find({'participants': 'mannu'}).toList();
    print("Test 2 ({'participants': 'mannu'}): ${test2.length} resultados");

    final test3 = await convCol.find(where.all('participants', ['mannu'])).toList();
    print("Test 3 (where.all('participants', ['mannu'])): ${test3.length} resultados");

    final test4 = await convCol.find({'participants': {'\$in': ['mannu']}}).toList();
    print("Test 4 ({'participants': {'\$in': ['mannu']}}): ${test4.length} resultados");

    await db.close();
  });
}
