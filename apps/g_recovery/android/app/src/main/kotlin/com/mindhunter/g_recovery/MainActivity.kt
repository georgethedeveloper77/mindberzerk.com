package com.mindhunter.g_recovery

import com.mindhunter.g_recovery.content.ContentHostApi
import com.mindhunter.g_recovery.content.ContentHostApiImpl
import com.mindhunter.g_recovery.recovery.RecoveryFlutterApi
import com.mindhunter.g_recovery.recovery.RecoveryHostApi
import com.mindhunter.g_recovery.recovery.RecoveryHostApiImpl
import com.mindhunter.g_recovery.storage.StorageHostApi
import com.mindhunter.g_recovery.storage.StorageHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var recovery: RecoveryHostApiImpl? = null
    private var storage: StorageHostApiImpl? = null
    private var content: ContentHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val recoveryImpl = RecoveryHostApiImpl(applicationContext)
        recoveryImpl.attachFlutterApi(RecoveryFlutterApi(messenger))
        RecoveryHostApi.setUp(messenger, recoveryImpl)
        recovery = recoveryImpl

        val storageImpl = StorageHostApiImpl(applicationContext)
        StorageHostApi.setUp(messenger, storageImpl)
        storage = storageImpl

        val contentImpl = ContentHostApiImpl(applicationContext)
        ContentHostApi.setUp(messenger, contentImpl)
        content = contentImpl
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Clearing every handler is not optional. A hot restart attaches a new
        // engine while the old handlers are still registered, and the stale ones
        // answer on a dead messenger.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        RecoveryHostApi.setUp(messenger, null)
        StorageHostApi.setUp(messenger, null)
        ContentHostApi.setUp(messenger, null)
        recovery?.dispose()
        storage?.dispose()
        content?.dispose()
        recovery = null
        storage = null
        content = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
