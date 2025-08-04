import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Import your service files
import 'auth_service.dart';
import 'firestore_service.dart';

// The main entry point of the app
void main() async {
  // These two lines are REQUIRED for Firebase to work and are the fix for the blank screen.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const WeatherApp());
}

// This widget handles the overall app theme and routing
class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthWrapper(), // Start with the authentication wrapper
      debugShowCheckedModeBanner: false,
    );
  }
}

// This widget checks if the user is logged in and shows the correct screen
class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();
  AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final User? user = snapshot.data;
          // If user is not logged in, show LoginScreen
          if (user == null) {
            return LoginScreen(authService: _authService);
          }
          // If user is logged in, show WeatherHomePage
          return WeatherHomePage(user: user, authService: _authService);
        }
        // Show a loading circle while checking the auth state
        return const Scaffold(
            backgroundColor: Color(0xFF1C1C2D),
            body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

// The Login Screen UI
class LoginScreen extends StatelessWidget {
  final AuthService authService;
  const LoginScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C2D),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login, color: Colors.white),
          label: const Text('Sign in with Google',
              style: TextStyle(color: Colors.white)),
          onPressed: () async {
            await authService.signInWithGoogle();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}

// Your Main Weather App Screen, now connected to Firebase
class WeatherHomePage extends StatefulWidget {
  final User user;
  final AuthService authService;
  const WeatherHomePage(
      {super.key, required this.user, required this.authService});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  static const String apiKey = '8719f0fdea93c9e2081c64bff87a12e4'; // Your API key
  final FirestoreService _firestoreService = FirestoreService();

  final List<CityWeather> _weatherList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    setState(() => _loading = true);

    _weatherList.clear(); // Clear the list before loading new data

    // READ favorites from Firestore using the user's unique ID
    List<String> cities =
        await _firestoreService.getFavoriteCities(widget.user.uid);

    if (cities.isEmpty) {
      // If a new user has no favorites, add default ones to Firestore
      const defaultCities = ['Kathmandu', 'Bhaktapur', 'Lalitpur'];
      for (var city in defaultCities) {
        await _firestoreService.addFavoriteCity(widget.user.uid, city);
      }
      cities = defaultCities; // Use the defaults for the initial load
    }

    for (var city in cities) {
      final weather = await fetchWeather(city);
      if (weather != null) {
        _weatherList.add(weather);
      }
    }
    // Check if the widget is still in the tree before calling setState
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<CityWeather?> fetchWeather(String city) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return CityWeather(
          city: data['name'],
          temp: data['main']['temp'].toDouble(),
          weatherMain: data['weather'][0]['main'],
          weatherDesc: data['weather'][0]['description'],
          humidity: data['main']['humidity'],
          wind: data['wind']['speed'].toDouble(),
          uv: 3, // UV data needs a separate API call, so we use a placeholder
        );
      }
    } catch (e) {
      print("Error fetching weather for $city: $e");
    }
    return null;
  }

  // CREATE a favorite city in Firestore
  void _addCity(String city) async {
    await _firestoreService.addFavoriteCity(widget.user.uid, city);
    _loadUserFavorites(); // Refresh the entire list from Firestore
  }

  // DELETE a favorite city from Firestore
  void _removeCity(String city) async {
    await _firestoreService.removeFavoriteCity(widget.user.uid, city);
    _loadUserFavorites(); // Refresh the entire list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C2D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
            'Hi, ${widget.user.displayName?.split(' ').first ?? 'User'}',
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () => widget.authService.signOut(),
          ),
        ],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              String newCity = '';
              return AlertDialog(
                title: const Text('Add City'),
                content: TextField(
                  onChanged: (val) => newCity = val,
                  decoration:
                      const InputDecoration(hintText: 'Enter city name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (newCity.isNotEmpty) {
                        _addCity(newCity); // Call the new _addCity method
                      }
                    },
                    child: const Text('Add'),
                  )
                ],
              );
            },
          );
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _weatherList.length,
              itemBuilder: (context, index) {
                return buildWeatherCard(_weatherList[index]);
              },
            ),
    );
  }

  Widget buildWeatherCard(CityWeather weather) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40), // Spacer to balance the delete icon
              Text(weather.city,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              // Add a delete button to the card
              IconButton(
                icon:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _removeCity(weather.city),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Chance of rain: 0%',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 16),
          const Icon(Icons.wb_sunny, size: 64, color: Colors.yellow),
          const SizedBox(height: 8),
          Text('${weather.temp.round()}°',
              style: const TextStyle(fontSize: 42, color: Colors.white)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              buildMiniCard('UV INDEX', '${weather.uv}'),
              buildMiniCard('WIND', '${weather.wind} km/h'),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildMiniCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: 120,
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16)),
        ],
      ),
    );
  }
}

// This class definition was missing before, causing all the errors.
class CityWeather {
  final String city;
  final double temp;
  final String weatherMain;
  final String weatherDesc;
  final int humidity;
  final double wind;
  final int uv;

  CityWeather({
    required this.city,
    required this.temp,
    required this.weatherMain,
    required this.weatherDesc,
    required this.humidity,
    required this.wind,
    required this.uv,
  });
}