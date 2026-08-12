package com.mindhunter.g_recovery

import com.mindhunter.g_recovery.apps.AppsHostApi
import com.mindhunter.g_recovery.apps.AppsHostApiImpl
import com.mindhunter.g_recovery.compare.CompareFlutterApi
import com.mindhunter.g_recovery.compare.CompareHostApi
import com.mindhunter.g_recovery.compare.CompareHostApiImpl
import com.mindhunter.g_recovery.compress.CompressHostApi
import com.mindhunter.g_recovery.compress.CompressHostApiImpl
import com.mindhunter.g_recovery.content.ContentHostApi
import com.mindhunter.g_recovery.content.ContentHostApiImpl
import com.mindhunter.g_recovery.hardware.HardwareHostApi
import com.mindhunter.g_recovery.hardware.HardwareHostApiImpl
import com.mindhunter.g_recovery.messages.MessagesHostApi
import com.mindhunter.g_recovery.messages.MessagesHostApiImpl
import com.mindhunter.g_recovery.recovery.RecoveryFlutterApi
import com.mindhunter.g_recovery.recovery.RecoveryHostApi
import com.mindhunter.g_recovery.recovery.RecoveryHostApiImpl
import com.mindhunter.g_recovery.server.ServerHostApi
import com.mindhunter.g_recovery.server.ServerHostApiImpl
import com.mindhunter.g_recovery.storage.StorageHostApi
import com.mindhunter.g_recovery.storage.StorageHostApiImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var recovery: RecoveryHostApiImpl? = null
    private var storage: StorageHostApiImpl? = null
    private var content: ContentHostApiImpl? = null
    private var messages: MessagesHostApiImpl? = null
    private var compare: CompareHostApiImpl? = null
    private var server: ServerHostApiImpl? = null
    private var apps: AppsHostApiImpl? = null
    private var hardware: HardwareHostApiImpl? = null
    private var compress: CompressHostApiImpl? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        val recoveryImpl = RecoveryHostApiImpl(applicationContext)
        recoveryImpl.attachFlutterApi(RecoveryFlutterApi(messenger))
        // The bridge runs on the application context, correctly, because it
        // outlives any one Activity. A runtime permission dialog is the single
        // thing it cannot do without one, so it borrows this and gives it back
        // in cleanUpFlutterEngine. Anything that keeps it longer leaks the
        // Activity across a hot restart.
        recoveryImpl.attachActivity(this)
        RecoveryHostApi.setUp(messenger, recoveryImpl)
        recovery = recoveryImpl

        val storageImpl = StorageHostApiImpl(applicationContext)
        StorageHostApi.setUp(messenger, storageImpl)
        storage = storageImpl

        val contentImpl = ContentHostApiImpl(applicationContext)
        ContentHostApi.setUp(messenger, contentImpl)
        content = contentImpl

        val messagesImpl = MessagesHostApiImpl(applicationContext)
        MessagesHostApi.setUp(messenger, messagesImpl)
        messages = messagesImpl

        // The activity is passed as a lambda, not a reference: a permission
        // dialog needs the CURRENT activity, and holding one across a
        // configuration change leaks it and then fails.
        val compressImpl = CompressHostApiImpl(applicationContext)
        CompressHostApi.setUp(messenger, compressImpl)
        compress = compressImpl

        val hardwareImpl = HardwareHostApiImpl(applicationContext) { this }
        HardwareHostApi.setUp(messenger, hardwareImpl)
        hardware = hardwareImpl

        val appsImpl = AppsHostApiImpl(applicationContext)
        AppsHostApi.setUp(messenger, appsImpl)
        apps = appsImpl

        val serverImpl = ServerHostApiImpl(applicationContext)
        ServerHostApi.setUp(messenger, serverImpl)
        server = serverImpl

        val compareImpl = CompareHostApiImpl(applicationContext)
        compareImpl.attachFlutterApi(CompareFlutterApi(messenger))
        CompareHostApi.setUp(messenger, compareImpl)
        compare = compareImpl
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Clearing every handler is not optional. A hot restart attaches a new
        // engine while the old handlers are still registered, and the stale ones
        // answer on a dead messenger.
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        RecoveryHostApi.setUp(messenger, null)
        StorageHostApi.setUp(messenger, null)
        ContentHostApi.setUp(messenger, null)
        MessagesHostApi.setUp(messenger, null)
        CompareHostApi.setUp(messenger, null)
        ServerHostApi.setUp(messenger, null)
        AppsHostApi.setUp(messenger, null)
        HardwareHostApi.setUp(messenger, null)
        CompressHostApi.setUp(messenger, null)
        recovery?.attachActivity(null)
        recovery?.dispose()
        storage?.dispose()
        content?.dispose()
        messages?.dispose()
        compare?.dispose()
        server?.dispose()
        apps?.dispose()
        hardware?.dispose()
        compress?.dispose()
        recovery = null
        storage = null
        content = null
        messages = null
        compare = null
        server = null
        apps = null
        hardware = null
        compress = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
