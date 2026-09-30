/**************************************************************************/
/*  libgodot_android.h                                                    */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if __has_include("core/extension/libgodot.h")
#include "core/extension/libgodot.h"
#elif __has_include("libgodot.h")
#include "libgodot.h"
#else
#error libgodot.h is required
#endif

#include <jni.h>

/**
 * @name libgodot_create_godot_instance_android
 * @since 4.4
 *
 * Creates a new Godot instance.
 *
 * @param p_argc The number of command line arguments.
 * @param p_argv The C-style array of command line arguments.
 * @param p_init_func GDExtension initialization function of the host application.
 * @param p_log_func Initialization log function, called with log message c string.
 * @param p_log_data User data passed to p_log_func.
 *
 * @return A pointer to created \ref GodotInstance GDExtension object or nullptr if there was an error.
 */
LIBGODOT_API GDExtensionObjectPtr libgodot_create_godot_instance_android(int p_argc, char *p_argv[], GDExtensionInitializationFunction p_init_func, LogCallbackFunction p_log_func, LogCallbackData p_log_data, JNIEnv *env, jobject p_asset_manager, jobject p_net_utils, jobject p_directory_access_handler, jobject p_file_access_handler, jobject p_godot_io_wrapper);

/**
 * @name libgodot_destroy_godot_instance
 * @since 4.4
 *
 * Destroys an existing Godot instance.
 *
 * @param p_godot_instance The reference to the GodotInstance object to destroy.
 *
 */
LIBGODOT_API void libgodot_destroy_godot_instance(GDExtensionObjectPtr p_godot_instance);

#ifdef __cplusplus
}
#endif
