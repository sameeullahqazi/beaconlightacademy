class StudentModel {
  String id;
  String grNo;
  String studentName;
  String img;

  StudentModel({
    required this.id,
    required this.grNo,
    required this.studentName,
    required this.img,
  });

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'].toString(),
      grNo: map['grNo'].toString(),
      studentName: map['studentName'] ?? '',
      img: map['img'] ?? '',
    );
  }
}
