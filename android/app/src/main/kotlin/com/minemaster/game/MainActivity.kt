package com.minemaster.game

import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Print Facebook App ID from resources
        try {
            val resId = resources.getIdentifier("facebook_app_id", "string", packageName)
            val fbAppId = if (resId != 0) resources.getString(resId) else "NOT_FOUND"
            Log.d("FB_CHECK", "facebook_app_id=$fbAppId")
        } catch (e: Exception) {
            Log.e("FB_CHECK", "Could not read facebook_app_id", e)
        }

        // Print key hash(es) from signing cert
        try {
            val info = packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )

            val signatures = info.signingInfo?.apkContentsSigners
            if (signatures == null) {
                Log.e("FB_CHECK", "signingInfo/apkContentsSigners is null")
            } else {
                for (sig in signatures) {
                    val md = MessageDigest.getInstance("SHA")
                    md.update(sig.toByteArray())
                    val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                    Log.d("FB_CHECK", "key_hash=$keyHash")
                }
            }
        } catch (e: Exception) {
            Log.e("FB_CHECK", "Could not compute key hash", e)
        }
    }
}