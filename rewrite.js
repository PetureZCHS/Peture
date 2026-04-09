const fs = require('fs');
const content = fs.readFileSync('lib/features/lost_pet/presentation/lost_pet_rescue_page.dart', 'utf-8');

const regex = /Widget _buildPosterPreview\(LostPetMaterials m\) \{[\s\S]*?Widget buildContent\(\) \{[\s\S]*?return RepaintBoundary\([\s\S]*?key: _posterKey,[\s\S]*?child: buildContent\(\),[\s\S]*?\);\n    \}/;

console.log(regex.test(content) ? 'Matched' : 'Not Matched');
