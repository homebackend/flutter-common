/*
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_common/app_logger.dart';

import 'cubit/settings/theme_cubit.dart';
import 'cubit/startup/app_initialization_cubit.dart';
import 'splash.dart';
import 'tool.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/auto_update_dialog.dart';

class MainApp extends StatefulWidget {
  final String githubOrganization;
  final String githubRepo;
  final String baseAssetName;
  final String appName;
  final String appIcon;
  final String upgradeFileName;
  final Color? appSeedColor;
  final Widget Function() mainApp;
  const MainApp(
    this.githubOrganization,
    this.githubRepo,
    this.baseAssetName,
    this.appName,
    this.appIcon,
    this.mainApp, {
    this.appSeedColor,
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
    WidgetsBinding.instance.addObserver(this);
    _appInitializationCubit = AppInitializationCubit(
      widget.githubOrganization,
      widget.githubRepo,
      widget.baseAssetName,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appInitializationCubit.checkUpdateRequired();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appInitializationCubit.close();
    super.dispose();
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
        BlocProvider(
          create: (_) =>
              ThemeCubit(seedColor: widget.appSeedColor)..setInitialTheme(),
        ),
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
                                AppInitializationState.showUpdateDetails ||
                            current.state == AppInitializationState.updateApp,
                        listener: (context, status) {
                          if (status.state ==
                              AppInitializationState.showUpdateDetails) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) => AppUpdateDialog(
                                downloadUrl: status.downloadUrl,
                                latestVersion: status.latestVersion,
                                changeLog: status.changeLog,
                              ),
                            );
                          } else {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => AutoUpdateDialog(
                                upgradeFileName: widget.upgradeFileName,
                                downloadUrl: status.downloadUrl,
                                latestVersion: status.latestVersion,
                                changeLog: status.changeLog,
                              ),
                            );
                          }
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
                          appLogger.e(
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
                            if (status.state ==
                                AppInitializationState.initialization) {
                              return SplashScreen(widget.appIcon);
                            } else {
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
