/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/settings/theme_cubit.dart';
import 'cubit/startup/app_initialization_cubit.dart';
import 'splash.dart';
import 'tool.dart';
import 'update_app.dart';
import 'widgets/app_update_detailer.dart';

class MainApp extends StatefulWidget {
  final String githubOrganization;
  final String githubRepo;
  final String baseAssetName;
  final String appName;
  final String appIcon;
  final String upgradeFileName;
  final Widget Function() mainApp;
  const MainApp(
    this.githubOrganization,
    this.githubRepo,
    this.baseAssetName,
    this.appName,
    this.appIcon,
    this.mainApp, {
    this.upgradeFileName = 'app-release.apk',
    super.key,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  late final AppInitializationCubit _appInitializationCubit;

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    _appInitializationCubit = AppInitializationCubit(
      widget.githubOrganization,
      widget.githubRepo,
      widget.baseAssetName,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appInitializationCubit.checkUpdateRequired();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()..setInitialTheme()),
        BlocProvider(create: (_) => _appInitializationCubit..initialize()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (_, themeState) => MaterialApp(
          title: widget.appName,
          debugShowCheckedModeBanner: false,
          theme: themeState.data,
          home: ScaffoldMessenger(
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  return MultiBlocListener(
                    listeners: [
                      BlocListener<
                        AppInitializationCubit,
                        AppInitializationStatus
                      >(
                        listenWhen: (_, current) =>
                            current.state ==
                            AppInitializationState.showUpdateDetails,
                        listener: (context, status) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) => AppUpdateDialog(
                              downloadUrl: status.downloadUrl,
                              latestVersion: status.latestVersion,
                              changeLog: status.changeLog,
                            ),
                          );
                        },
                      ),
                      BlocListener<
                        AppInitializationCubit,
                        AppInitializationStatus
                      >(
                        listenWhen: (_, current) =>
                            current.state ==
                            AppInitializationState.updateCheckFailed,
                        listener: (_, status) {
                          log(
                            'Error during check for App update: ${status.error}',
                          );
                          showSnackBar(
                            context,
                            'Unable to check for App update',
                          );
                        },
                      ),
                    ],
                    child:
                        BlocBuilder<
                          AppInitializationCubit,
                          AppInitializationStatus
                        >(
                          builder: (context, status) {
                            switch (status.state) {
                              case AppInitializationState.initialization:
                                return SplashScreen(widget.appIcon);
                              case AppInitializationState.showUpdateDetails:
                                return widget.mainApp();
                              case AppInitializationState.updateApp:
                                return UpdateApp(
                                  widget.appName,
                                  widget.upgradeFileName,
                                  status.downloadUrl,
                                  status.latestVersion,
                                  status.changeLog,
                                  () => context
                                      .read<AppInitializationCubit>()
                                      .emitInitialized(),
                                );
                              case AppInitializationState.initialized:
                                return widget.mainApp();
                              case AppInitializationState.updateCheckFailed:
                                return widget.mainApp();
                            }
                          },
                        ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
