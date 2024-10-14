class Assistant {
  String id, name;
  String? model, instructions, description;

  Assistant({
    required this.id,
    required this.name,
    required this.model,
    this.instructions,
    this.description,
  });

  factory Assistant.fromMap(Map<String, dynamic> map) {
    return Assistant(
      id: map['id'],
      name: map['name'],
      model: map['model'],
      instructions: map['instructions'],
      description: map['description'],
    );
  }
}
