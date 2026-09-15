package com.mindhunter.g_launcher.system

import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.util.Log

/**
 * PHASE L6c: what is playing, and the buttons to change it.
 *
 * ─── IT RIDES THE BADGE GRANT AND ADDS NOTHING ──────────────────────────────
 *
 * `MediaSessionManager.getActiveSessions` takes the ComponentName of an ENABLED
 * `NotificationListenerService` and refuses anything else. This app already
 * ships one for badges, already declares it in the manifest, already asks for
 * the grant, and already discloses it. So media costs no new permission, no new
 * Play surface and no new Data Safety line.
 *
 * ─── AND IT IS NOT INSIDE THE SERVICE ───────────────────────────────────────
 *
 * The obvious reading of that API is that the query belongs in the service, and
 * it does not: the service's component is an ARGUMENT, so anything holding a
 * Context can ask. Putting it inside would have coupled the media path to the
 * badge path's lifecycle, and the badge service is a push pipeline that
 * broadcasts on every notification change. Media is pulled, when a row opens.
 * Two different shapes sharing a class is how one of them ends up firing on the
 * other's schedule.
 *
 * ─── NOTHING IS CACHED, AND NOTHING IS OBSERVED ─────────────────────────────
 *
 * No `addOnActiveSessionsChangedListener`, deliberately. A registered callback
 * lives for the life of the process and fires on every track change on the
 * phone, whether or not anything is looking. This is read when a row opens, one
 * binder call, and the answer is stale the moment it is returned in exactly the
 * way a paused track is: pressing play on a session that just ended returns
 * false, which the caller already handles.
 */
object MediaSessions {

    private const val TAG = "GLauncherMedia"

    /**
     * Every active session, most recent first.
     *
     * The platform returns them in priority order, which is what a user means
     * by "the one that is playing": the most recently active session leads,
     * and that is the order the caller should keep.
     *
     * Empty on every failure, and the failures are ordinary. No grant is the
     * normal state for anyone who has not turned badges on, and a
     * `SecurityException` is what that looks like from here.
     */
    fun active(context: Context): List<MediaController> {
        val app = context.applicationContext
        if (!BadgeBridge.isEnabled(app)) return emptyList()

        return try {
            val manager = app.getSystemService(Context.MEDIA_SESSION_SERVICE)
                as MediaSessionManager
            manager.getActiveSessions(
                ComponentName(app, NotificationBadgeService::class.java),
            )
        } catch (e: SecurityException) {
            // The grant went away between the check above and this call, which
            // is a real race: revoking it does not stop the process.
            Log.i(TAG, "sessions denied: $e")
            emptyList()
        } catch (e: Exception) {
            Log.w(TAG, "sessions failed: $e")
            emptyList()
        }
    }

    /**
     * True when this session is genuinely producing sound.
     *
     * BUFFERING and CONNECTING count as playing, because the user pressed play
     * and the button must not flip back to a play glyph while the stream opens.
     * Everything else, including FAST_FORWARDING and ERROR, does not.
     */
    fun isPlaying(state: PlaybackState?): Boolean = when (state?.state) {
        PlaybackState.STATE_PLAYING,
        PlaybackState.STATE_BUFFERING,
        PlaybackState.STATE_CONNECTING,
        -> true
        else -> false
    }

    /**
     * Whether the session will accept a skip in this direction.
     *
     * ─── ASKED, NOT ASSUMED ─────────────────────────────────────────────────
     *
     * `PlaybackState.actions` is the session's own declaration of what it
     * supports, and it varies enormously: a podcast app commonly offers
     * neither skip, an audiobook offers seek and no skip, a radio stream offers
     * nothing. Drawing both buttons and having them do nothing is the
     * live-and-inert failure this codebase keeps finding in its settings, one
     * surface over.
     */
    fun can(state: PlaybackState?, action: Long): Boolean =
        state != null && (state.actions and action) != 0L

    /**
     * Send one command to the session owned by [packageName].
     *
     * False when nothing owns a session for that package any more, which is the
     * common case a second after a track ends, or when the transport refuses.
     * Refusal is not an error worth logging loudly: the caller reports it and
     * the button settles back.
     */
    fun send(context: Context, packageName: String, command: String): Boolean {
        val controller = active(context)
            .firstOrNull { it.packageName == packageName }
            ?: return false

        return try {
            val t = controller.transportControls
            when (command) {
                "play" -> t.play()
                "pause" -> t.pause()
                "next" -> t.skipToNext()
                "previous" -> t.skipToPrevious()
                // A command from a newer build. Ignored rather than thrown:
                // this runs on a tap and an exception here would take the
                // drawer down for a button that should simply do nothing.
                else -> return false
            }
            true
        } catch (e: Exception) {
            Log.w(TAG, "command '$command' failed for $packageName: $e")
            false
        }
    }
}
