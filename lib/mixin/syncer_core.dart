/*
 * Copyright (c) 2026 Neeraj Jakhar
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin SyncerCore<DataType> implements WidgetsBindingObserver {
  bool isSyncInProgress = false;
  bool isModified = false;
  DateTime _lastFetch = DateTime(0);

  SharedPreferences get sharedPreferences;
  FlutterSecureStorage get secureStorage;
  http.Client get client;

  String get keyHasSyncDataModified;
  String get keyDocumentLastModified;
  String get keyDocumentSha;

  String? appSha;
  String? appEtag;

  bool get isModifiable;
  String get localFileName;
  Duration get syncDuration;

  void notifySyncStarted();
  void notifySyncDone();
  void notifySyncFailed();
  Future<void> processContentPostLoad(Uint8List content);
  Future<void> processConflicts(Uint8List serverData, String serverSha);
  Future<void> syncDataLoader();
  Future<void> notifyLoadedFromCache();
  Future<void> notifyLoadedFromNetwork();
  Future<void> notifyLoadErrorOccurred();
  Future<(int statusCode, String? version, String? etag, Uint8List? data)>
  fetchRemote({String? lastModified, String? documentSha});
  Future<
    (
      PushReturnCode statusCode,
      String? newVersion,
      String? newEtag,
      http.Response raw,
    )
  >
  pushRemote(Uint8List bytes, {String? fileSha});

  Future<Uint8List> getContentsForWrite() async {
    final cacheFile = await _cacheFile();
    return await cacheFile.readAsBytes();
  }

  Timer? _syncTimer;

  Future<void> initializeSyncer() async {
    appSha = sharedPreferences.getString(keyDocumentSha);
    appEtag = sharedPreferences.getString(keyDocumentLastModified);
    isModified = sharedPreferences.getBool(keyHasSyncDataModified) ?? false;

    WidgetsBinding.instance.addObserver(this);
    await _loadSyncData();
    _startTimer();
  }

  void disposeSyncer() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _syncFromNetwork(true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromNetwork(true);
      _startTimer();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _syncTimer?.cancel();
    }
  }

  Future<void> syncData() => _syncFromNetwork(true);

  Future<void> _loadSyncData() async {
    final cacheFile = await _cacheFile();
    final cacheFileExists =
        cacheFile.existsSync() && appEtag != null && appEtag!.isNotEmpty;
    if (cacheFileExists) {
      unawaited(
        _syncFromNetwork(true).catchError((e) async {
          log('Error during background sync: $e');
          notifySyncFailed();
          await processContentPostLoad(await cacheFile.readAsBytes());
        }),
      );
      await processContentPostLoad(await cacheFile.readAsBytes());
    } else {
      await _syncFromNetwork(false);
    }
  }

  Future<void> cacheLocally(Uint8List bytes, String sha, String etag) async {
    appSha = sha;
    appEtag = etag;
    final cacheFile = await _cacheFile();
    await cacheFile.writeAsBytes(bytes);
    await sharedPreferences.setString(keyDocumentSha, sha);
    await sharedPreferences.setString(keyDocumentLastModified, etag);
  }

  Future<void> _syncFromNetwork(bool background) async {
    if (isSyncInProgress) {
      return;
    }

    try {
      isSyncInProgress = true;
      if (isModifiable && isModified) {
        await _saveToNetwork();
      } else {
        if (DateTime.now().difference(_lastFetch) > syncDuration) {
          await _loadFromNetwork(background);
          _lastFetch = DateTime.now();
        }
      }
    } finally {
      isSyncInProgress = false;
    }
  }

  Future<void> _saveToNetwork() async {
    await pushWithAutoMerge();
    final cacheFile = await _cacheFile();
    await processContentPostLoad(await cacheFile.readAsBytes());
  }

  Future<void> _loadFromNetwork(bool background) async {
    bool thereWasException = false;

    try {
      notifySyncStarted();
      final cacheFile = await _cacheFile();
      final lastMod = cacheFile.existsSync() ? appEtag : '';
      final documentSha = cacheFile.existsSync() ? appSha : '';
      final (code, sha, etag, bytes) = await fetchRemote(
        lastModified: lastMod,
        documentSha: documentSha,
      );

      if (cacheFile.existsSync() && code == 304) {
        notifyLoadedFromCache();
        log('Loaded from cache: ${runtimeType.toString()}');
        await processContentPostLoad(await cacheFile.readAsBytes());
      } else if (code == 200 && bytes != null) {
        notifyLoadedFromNetwork();
        await cacheLocally(bytes, sha!, etag!);
        await processContentPostLoad(bytes);
        if (background) {
          // If cacheFileExists is true that means earlier
          // we loaded data from cache and now new version
          // of cache is available. So notify.
          syncDataLoader();
        }
      } else {
        notifyLoadErrorOccurred();
        log('Error during http call: $code for ${runtimeType.toString()}');
        throw (Exception('HTTP $code'));
      }
    } catch (e) {
      thereWasException = true;
      log('Error: $e');
      notifySyncFailed();
      rethrow;
    } finally {
      if (!thereWasException) {
        notifySyncDone();
      }
    }
  }

  Future<void> pushWithAutoMerge({String? retryServerFileSha}) async {
    bool thereWasException = false;

    try {
      notifySyncStarted();
      final bytes = await getContentsForWrite();
      final (code, fileSha, fileEtag, res) = await pushRemote(
        bytes,
        fileSha: retryServerFileSha ?? appSha,
      );
      if (code == PushReturnCode.success) {
        await cacheLocally(bytes, fileSha ?? '', fileEtag ?? '');
      } else if (code == PushReturnCode.conflict) {
        final (code, serverFileSha, serverFileEtag, serverData) =
            await fetchRemote();

        if (serverFileSha == null || serverData == null) {
          throw Exception('Failed to fetch latest for merge');
        }

        await processConflicts(serverData, serverFileSha);
      } else {
        throw Exception("Push error: ${res.body}");
      }
    } catch (_) {
      thereWasException = true;
      notifySyncFailed();
      rethrow;
    } finally {
      if (!thereWasException) {
        isModified = false;
        await setSyncDataModified(false);
        notifySyncDone();
      }
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationCacheDirectory();
    return File('${dir.path}/$localFileName');
  }

  Future<bool> hasSyncDataModified() async {
    return isModified;
  }

  Future<void> setSyncDataModified(bool modified) async {
    isModified = modified;
    await sharedPreferences.setBool(keyHasSyncDataModified, modified);
  }
}

enum PushReturnCode { success(), error(), conflict() }
