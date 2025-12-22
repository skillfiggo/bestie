class MockProfile {
  final String id;
  final String name;
  final int age;
  final String location;
  final String distance;
  final String imageUrl;
  final bool isOnline;
  final String gender;
  final double rating;

  const MockProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.location,
    required this.distance,
    required this.imageUrl,
    this.isOnline = false,
    required this.gender,
    this.rating = 4.5,
  });

  // Mock Data Generator
  static List<MockProfile> getMockProfiles({String userGender = 'male'}) {
    // If user is male, show females. If female, show males.
    final targetGender = userGender == 'male' ? 'female' : 'male';
    
    if (targetGender == 'female') {
      return [
        const MockProfile(
          id: '1',
          name: 'Sarah',
          age: 24,
          location: 'New York, USA',
          distance: '> 5 km',
          imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
          isOnline: true,
          gender: 'female',
          rating: 4.8,
        ),
        const MockProfile(
          id: '2',
          name: 'Emily',
          age: 22,
          location: 'London, UK',
          distance: '< 1 km',
          imageUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9',
          isOnline: false,
          gender: 'female',
          rating: 4.2,
        ),
        const MockProfile(
          id: '3',
          name: 'Jessica',
          age: 26,
          location: 'Paris, France',
          distance: '3 km',
          imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
          isOnline: true,
          gender: 'female',
          rating: 5.0,
        ),
        const MockProfile(
          id: '4',
          name: 'Sophia',
          age: 23,
          location: 'Toronto, Canada',
          distance: '> 10 km',
          imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e',
          isOnline: true,
          gender: 'female',
          rating: 4.5,
        ),
        const MockProfile(
          id: '5',
          name: 'Olivia',
          age: 25,
          location: 'Berlin, Germany',
          distance: '7 km',
          imageUrl: 'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df',
          isOnline: false,
          gender: 'female',
          rating: 4.7,
        ),
      ];
    } else {
      return [
        const MockProfile(
          id: '6',
          name: 'James',
          age: 27,
          location: 'Chicago, USA',
          distance: '2 km',
          imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
          isOnline: true,
          gender: 'male',
          rating: 4.6,
        ),
        const MockProfile(
          id: '7',
          name: 'Michael',
          age: 29,
          location: 'Sydney, Australia',
          distance: '> 20 km',
          imageUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d',
          isOnline: false,
          gender: 'male',
          rating: 3.9,
        ),
        const MockProfile(
          id: '8',
          name: 'David',
          age: 25,
          location: 'Miami, USA',
          distance: '< 500 m',
          imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
          isOnline: true,
          gender: 'male',
          rating: 4.9,
        ),
      ];
    }
  }
}
