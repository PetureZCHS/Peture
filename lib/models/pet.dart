class Pet {
  final int? id;
  final String type;
  final String name;
  final String age;
  final String gender;
  final String breed;

  Pet({
    this.id,
    required this.type,
    required this.name,
    required this.age,
    required this.gender,
    required this.breed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'age': age,
      'gender': gender,
      'breed': breed,
    };
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      id: map['id'],
      type: map['type'],
      name: map['name'],
      age: map['age'],
      gender: map['gender'],
      breed: map['breed'],
    );
  }
}
