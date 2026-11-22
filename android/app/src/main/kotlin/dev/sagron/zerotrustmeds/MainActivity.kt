package dev.sagron.zerotrustmeds

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity, not FlutterActivity: the biometric prompt
 * (local_auth) needs a FragmentActivity.
 *
 * Channel `zt_meds/links` holds caregiver invite links the app was opened
 * with, until the unlocked app takes them.
 *
 * Channel `zt_meds/text_pick` answers ZT Keyboard's "Insert from ZT apps" key
 * (see [TextPick]): the keyboard opens Meds, the user unlocks and taps what to type.
 */
class MainActivity : FlutterFragmentActivity() {
    private var links: MethodChannel? = null
    private val pending = mutableListOf<String>()

    /** ZT Keyboard is waiting for the user to pick a text here (see [TextPick]). */
    private var pickingText = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (TextPick.isPick(intent)) {
            // Only another Zero-Trust app may ask; anyone else gets nothing.
            if (TextPick.callerAllowed(this)) pickingText = true else TextPick.answer(this, null)
        }
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_meds/text_pick")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // configureFlutterEngine runs inside super.onCreate, before pickingText
                    // is set, so the question is answered from the intent and the caller check.
                    "isPick" -> result.success(TextPick.isPick(intent) && TextPick.callerAllowed(this))
                    "finish" -> {
                        // Answers only the screen the keyboard itself opened.
                        if (pickingText) {
                            pickingText = false
                            TextPick.answer(this, call.argument<String>("text"))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // A pick request is only honoured when it opens its own screen (onCreate), where
        // Android tells who is asking.
        if (TextPick.isPick(intent)) return
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
