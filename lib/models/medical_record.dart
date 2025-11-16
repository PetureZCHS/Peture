// 医疗记录模型类
class MedicalRecord {
  final int? id;
  final String date;
  final String description;
  final int? petId;

  MedicalRecord({
    this.id,
    required this.date,
    required this.description,
    this.petId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'description': description,
      'pet_id': petId,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    return MedicalRecord(
      id: map['id'],
      date: map['date'],
      description: map['description'],
      petId: map['pet_id'],
    );
  }
}

// 宠物档案模型类
class PetProfile {
  final int? id;
  final String name;
  final String age;
  final String breed;
  final String weight;
  final String status;

  PetProfile({
    this.id,
    required this.name,
    required this.age,
    required this.breed,
    required this.weight,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'breed': breed,
      'weight': weight,
      'status': status,
    };
  }

  factory PetProfile.fromMap(Map<String, dynamic> map) {
    return PetProfile(
      id: map['id'],
      name: map['name'],
      age: map['age'],
      breed: map['breed'],
      weight: map['weight'],
      status: map['status'],
    );
  }
}

// 每日提醒模型类
class DailyReminder {
  final int? id;
  final String time;
  final String task;
  final int? petId;

  DailyReminder({this.id, required this.time, required this.task, this.petId});

  Map<String, dynamic> toMap() {
    return {'id': id, 'time': time, 'task': task, 'pet_id': petId};
  }

  factory DailyReminder.fromMap(Map<String, dynamic> map) {
    return DailyReminder(
      id: map['id'],
      time: map['time'],
      task: map['task'],
      petId: map['pet_id'],
    );
  }
}

// 体重记录模型类
class WeightRecord {
  final int? id;
  final String date;
  final double weight;
  final String? notes;
  final int? petId;

  WeightRecord({
    this.id,
    required this.date,
    required this.weight,
    this.notes,
    this.petId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'weight': weight,
      'notes': notes,
      'pet_id': petId,
    };
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: map['id'],
      date: map['date'],
      weight: map['weight'],
      notes: map['notes'],
      petId: map['pet_id'],
    );
  }
}

// 疫苗记录模型类
class VaccineRecord {
  final int? id;
  final String date;
  final String type;
  final String name;
  final String nextDueDate;
  final int? petId;

  VaccineRecord({
    this.id,
    required this.date,
    required this.type,
    required this.name,
    required this.nextDueDate,
    this.petId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'type': type,
      'name': name,
      'nextDueDate': nextDueDate,
      'pet_id': petId,
    };
  }

  factory VaccineRecord.fromMap(Map<String, dynamic> map) {
    return VaccineRecord(
      id: map['id'],
      date: map['date'],
      type: map['type'],
      name: map['name'],
      nextDueDate: map['nextDueDate'],
      petId: map['pet_id'],
    );
  }
}
