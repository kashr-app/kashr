import 'package:finanalyzer/home_page.dart';
import 'package:finanalyzer/settings/settings_cubit.dart';
import 'package:finanalyzer/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SettingsPage();
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, state) => ListTile(
                    title: const Text("Theme Mode"),
                    subtitle: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text("System"),
                          icon: Icon(Icons.brightness_6),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text("Light"),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text("Dark"),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: <ThemeMode>{state.themeMode},
                      onSelectionChanged: (value) =>
                          context.read<SettingsCubit>().setTheme(value.first),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
