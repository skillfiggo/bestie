class VisitorModel {
  final String id;
  final String name;
  final int age;
  final String imageUrl;
  final String visitTime;

  const VisitorModel({
    required this.id,
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.visitTime,
  });
}

class MockVisitors {
  static List<VisitorModel> getVisitedMe() {
    return [
      const VisitorModel(
        id: '1',
        name: 'Lily',
        age: 23,
        imageUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
        visitTime: '2m ago',
      ),
      const VisitorModel(
        id: '2',
        name: 'Sophia',
        age: 25,
        imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
        visitTime: '1h ago',
      ),
      const VisitorModel(
        id: '3',
        name: 'Emma',
        age: 22,
        imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
        visitTime: '5h ago',
      ),
    ];
  }

  static List<VisitorModel> getIVisited() {
    return [
      const VisitorModel(
        id: '4',
        name: 'Olivia',
        age: 24,
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        visitTime: '10m ago',
      ),
      const VisitorModel(
        id: '5',
        name: 'Ava',
        age: 26,
        imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
        visitTime: 'Yesterday',
      ),
    ];
  }
}
