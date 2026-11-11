package dev.sagron.zerotrustmeds

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 *
 * Channel `zt_meds/links` holds caregiver invite links the app was opened
 * with, until the unlocked app takes them.
 */
class MainActivity : FlutterFragmentActivity() {
    private var links: MethodChannel? = null
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        links = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_meds/links").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val out = ArrayList(pending)
                        pending.clear()
                        result.success(out)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        if (uri.host != "zerotrust.bz" || uri.path?.startsWith("/join") != true) return
        // Taken once: rotating the screen must not open it again.
        intent.action = null
        pending.add(uri.toString())
        links?.invokeMethod("linksArrived", null)
    }
}
