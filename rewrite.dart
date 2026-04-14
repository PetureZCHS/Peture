import 'dart:io';

void main() {
  final file =
      File('lib/features/lost_pet/presentation/lost_pet_rescue_page.dart');
  final content = file.readAsStringSync();

  final regex = RegExp(
    r'Widget _buildPosterPreview\(LostPetMaterials m\) \{.*?return RepaintBoundary\(.*?key: _posterKey,.*?child: buildContent\(\),.*?\);\n    \}',
    multiLine: true,
    dotAll: true,
  );

  print(regex.hasMatch(content) ? 'Matched' : 'Not Matched');
}
