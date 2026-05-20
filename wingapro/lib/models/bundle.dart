class Bundle {
  final String id;
  final String title;
  final String description;
  final String price;
  final String expiryDate;
  final String imagePath; // local file path or base64
  final DateTime createdAt;

  Bundle({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.expiryDate,
    required this.imagePath,
    required this.createdAt,
  });
}