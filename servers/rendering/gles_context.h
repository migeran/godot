/**************************************************************************/
/*  gles_context.h                                                        */
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

#ifndef GLES_CONTEXT_H
#define GLES_CONTEXT_H

#include "core/object/class_db.h"
#include "core/object/ref_counted.h"
#include "servers/display_server.h"
#include "servers/rendering/rendering_native_surface.h"

class GLESContext {
public:
	virtual void initialize() = 0;
	virtual bool create_framebuffer(DisplayServer::WindowID p_id, Ref<RenderingNativeSurface> p_native_surface) = 0;
	virtual void resized(DisplayServer::WindowID p_id) = 0;
	virtual void begin_rendering(DisplayServer::WindowID p_id) = 0;
	virtual void end_rendering(DisplayServer::WindowID p_id) = 0;
	virtual bool destroy_framebuffer(DisplayServer::WindowID p_id) = 0;
	virtual void deinitialize() = 0;
	virtual uint64_t get_fbo(DisplayServer::WindowID p_id) const = 0;

	virtual ~GLESContext() {}
};

#endif // GLES_CONTEXT_H
