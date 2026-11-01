package io.github.hik4.todorbit

import android.accounts.Account
import android.content.Context
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.Scope
import io.flutter.plugin.common.MethodChannel

internal fun driveAuthorizationRequest(interactive: Boolean, account: String?): AuthorizationRequest {
    val builder=AuthorizationRequest.builder().setRequestedScopes(listOf(Scope("https://www.googleapis.com/auth/drive.appdata")))
    if(interactive) builder.setPrompt(AuthorizationRequest.Prompt.SELECT_ACCOUNT)
    else if(account!=null && account.contains('@')) builder.setAccount(Account(account,"com.google"))
    return builder.build()
}

/** Silent authorization only. A resolution is deferred to the unlocked UI. */
internal class BackgroundDriveAuthorization(private val context: Context) {
    private var generation=0
    private var token: String?=null
    fun cancel() {generation++;token=null}
    fun authorize(account: String?, force: Boolean, result: MethodChannel.Result) {
        val current=generation
        if(account==null || !account.contains('@') ||
            GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(context)!=ConnectionResult.SUCCESS) {
            result.error("reconnect","Open unlocked Todorbit and reconnect Google Drive to resume pending sync.",null);return
        }
        val client=Identity.getAuthorizationClient(context)
        fun request() {
            if(current!=generation) return
            client.authorize(driveAuthorizationRequest(false,account)).addOnSuccessListener { authorization ->
                if(current!=generation) return@addOnSuccessListener
                if(authorization.hasResolution()) {
                    result.error("reconnect","Google authorization needs interaction. Reconnect in unlocked Todorbit; pending work is retained.",null)
                } else {
                    token=authorization.accessToken
                    result.success(token)
                }
            }.addOnFailureListener {
                if(current==generation) result.error("reconnect","Google authorization could not refresh in the background. Open Todorbit to reconnect.",null)
            }
        }
        if(force && token!=null) client.clearToken(ClearTokenRequest.builder().setToken(token!!).build()).addOnCompleteListener {request()}
        else request()
    }
}
