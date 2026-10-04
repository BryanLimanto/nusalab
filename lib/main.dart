import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/publications_screen.dart';
import 'services/api_client.dart';
import 'state/chat_controller.dart';
import 'state/proposal_controller.dart';
import 'state/repository_search_controller.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TaRepositoryApp());
}

/// Entry point: wires the API client into the two controllers and exposes them through
/// `provider`.
class TaRepositoryApp extends StatelessWidget {
  const TaRepositoryApp({super.key, this.apiClient});

  /// Injectable so tests can supply a fake transport.
  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final api = apiClient ?? ApiClient();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RepositorySearchController>(
          create: (_) => RepositorySearchController(api),
        ),
        ChangeNotifierProvider<ChatController>(
          create: (_) => ChatController(api),
        ),
        ChangeNotifierProvider<ProposalController>(
          create: (_) => ProposalController(api),
        ),
      ],
      child: MaterialApp(
        title: 'Repository TA UKP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routes: <String, WidgetBuilder>{
          HomeScreen.routeName: (_) => const HomeScreen(),
          PublicationsScreen.routeName: (_) => const PublicationsScreen(),
        },
        initialRoute: HomeScreen.routeName,
      ),
    );
  }
}
