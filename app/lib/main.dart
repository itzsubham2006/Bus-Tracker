import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:college_bus_tracker/providers/bus_provider.dart';
import 'package:college_bus_tracker/providers/driver_provider.dart';
import 'package:college_bus_tracker/screens/home_screen.dart';

/// Entry point of the College Bus Tracker app.
///
/// The app opens directly into the student view (map with bus markers).
/// There is NO login/signup for students. Driver mode is hidden behind
/// a secret long-press gesture on the app bar title.
void main() {
  runApp(const CollegeBusApp());
}

class CollegeBusApp extends StatelessWidget {
  const CollegeBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider makes BusProvider and DriverProvider available
    // to every widget in the tree via context.watch<T>() or context.read<T>()
    return MultiProvider(
      providers: [
        // BusProvider: manages the list of buses + SSE connection
        // It starts fetching bus data and connecting to SSE immediately
        ChangeNotifierProvider(create: (_) => BusProvider()),

        // DriverProvider: manages driver auth + location sending
        // On creation, it checks if a saved token exists from a previous session
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: MaterialApp(
        title: 'College Bus Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Material 3 design with indigo as the primary color
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        // HomeScreen is the student view — the default screen for everyone
        home: const HomeScreen(),
      ),
    );
  }
}
