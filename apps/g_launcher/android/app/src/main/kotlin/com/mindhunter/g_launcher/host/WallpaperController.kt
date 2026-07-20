package com.mindhunter.g_launcher.host

/**
 * PHASE 4.
 *
 * WallpaperManager: set the theme's wallpaper, and read the system wallpaper
 * so the dock's translucency has something real to blur against.
 *
 * Setting a wallpaper needs SET_WALLPAPER (a normal permission, no prompt).
 * Reading it needs READ_EXTERNAL_STORAGE on older APIs - prefer not to read at
 * all; draw the theme's own wallpaper asset instead and dodge the permission.
 */
