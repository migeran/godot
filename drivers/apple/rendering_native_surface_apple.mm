/**************************************************************************/
/*  rendering_native_surface_apple.mm                                     */
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

#include "rendering_native_surface_apple.h"

#import "drivers/apple/rendering_context_driver_vulkan_apple.h"
#include "drivers/gles3/rasterizer_gles3.h"
#include "drivers/gles3/storage/texture_storage.h"
#include "drivers/metal/rendering_context_driver_metal.h"
#include "servers/rendering/gl_manager.h"

#import <QuartzCore/CAMetalLayer.h>

#if defined(GLES3_ENABLED)
#import <QuartzCore/QuartzCore.h>

#if defined(IOS_ENABLED)
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#endif

#if defined(MACOS_ENABLED)
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>
#include <dlfcn.h>
#endif

#if defined(MACOS_ENABLED)
typedef CGLContextObj (*CGLGetCurrentContextPtr)(void);
typedef CGLError (*CGLTexImageIOSurface2DPtr)(CGLContextObj ctx, GLenum target, GLenum internal_format,
		GLsizei width, GLsizei height, GLenum format, GLenum type, IOSurfaceRef ioSurface, GLuint plane);
typedef const char *(*CGLErrorStringPtr)(CGLError);
#endif

#if defined(MACOS_ENABLED)
static constexpr uint32_t MACOS_BUFFER_COUNT = 3;
static constexpr GLint MACOS_MAX_BACKING_SIZE = 16384;

struct MacOSFrameBuffer {
	IOSurfaceRef surface = nullptr;
	GLuint colorTexture = 0;
	GLuint framebuffer = 0;
};
#endif

#if defined(EGL_STATIC)
#include "drivers/egl/gl_manager_embedded_angle.h"
#endif
#endif

#include "rendering_native_surface_apple.h"

#include "core/os/os.h"
#include "drivers/gles3/storage/texture_storage.h"
#include "drivers/metal/rendering_context_driver_metal.h"
#include "servers/rendering/gl_manager.h"

#if defined(GLES3_ENABLED)

#include "drivers/egl/gl_manager_embedded_angle.h"

#import "platform/ios/os_ios.h"

struct WindowData {
	GLint backingWidth = 0;
	GLint backingHeight = 0;
	GLuint viewRenderbuffer = 0;
	GLuint viewFramebuffer = 0;
	GLuint depthRenderbuffer = 0;
#if defined(IOS_ENABLED)
	CAEAGLLayer *layer = nullptr;
#endif
#if defined(MACOS_ENABLED)
	CALayer *layer = nullptr;
	MacOSFrameBuffer framebuffers[MACOS_BUFFER_COUNT];
	uint32_t currentFramebuffer = 0;
	bool framebuffersValid = false;
#endif
};

#define GL_ERR(expr) \
	{ \
		expr; \
		GLenum err = glGetError(); \
		if (err) { \
			NSLog(@"%s:%s: %x error", __FUNCTION__, #expr, err); \
		} \
	}

class GLManagerApple : public GLManager {
	DisplayServerEnums::WindowID current_window = -1;

public:
	virtual Error initialize(void *p_native_display = nullptr) override;
	virtual Error open_display(void *p_native_display = nullptr) override { return OK; }
	virtual Error window_create(DisplayServerEnums::WindowID p_id, Ref<RenderingNativeSurface> p_native_surface, int p_width, int p_height) override;
	virtual void window_resize(DisplayServerEnums::WindowID p_id, int p_width, int p_height) override;
	virtual void window_make_current(DisplayServerEnums::WindowID p_id) override;
	virtual Size2i window_get_size(DisplayServerEnums::WindowID p_id) const override;
	virtual void release_current() override {}
	virtual void swap_buffers() override;
	virtual void window_destroy(DisplayServerEnums::WindowID p_id) override;
	void deinitialize();

	virtual void set_use_vsync(bool p_use) override {}
	virtual bool is_using_vsync() const override { return false; }
	virtual bool validate_driver() const override { return true; }

	virtual int window_get_render_target(DisplayServerEnums::WindowID p_window_id) const override;
	virtual int window_get_color_texture(DisplayServerEnums::WindowID p_id) const override { return 0; }

	virtual ~GLManagerApple() {
		deinitialize();
	}

protected:
	Error create_framebuffer(DisplayServerEnums::WindowID p_id, void *p_layer, int p_width, int p_height);
#if defined(MACOS_ENABLED)
	void destroy_framebuffers(WindowData &p_gles_data, bool p_clear_layer_contents);
#endif

private:
	HashMap<DisplayServerEnums::WindowID, WindowData> windows;
#if defined(IOS_ENABLED)
	EAGLContext *context = nullptr;
#elif defined(MACOS_ENABLED)
	NSOpenGLContext *context = nullptr;
	bool framework_loaded = false;
	CGLGetCurrentContextPtr cgl_get_current_context = nullptr;
	CGLTexImageIOSurface2DPtr cgl_tex_image_iosurface_2d = nullptr;
	CGLErrorStringPtr cgl_error_string = nullptr;

	Error load_opengl_framework();
#endif
};

#if defined(MACOS_ENABLED)
Error GLManagerApple::load_opengl_framework() {
	if (framework_loaded) {
		return OK;
	}

	NSBundle *framework = [NSBundle bundleWithIdentifier:@"com.apple.opengl"];
	ERR_FAIL_COND_V_MSG(framework == nil || ![framework load], ERR_CANT_CREATE, "Failed to load OpenGL framework.");

	void *library_handle = dlopen([framework.executablePath UTF8String], RTLD_NOW);
	ERR_FAIL_NULL_V_MSG(library_handle, ERR_CANT_CREATE, "Failed to open OpenGL framework.");

	cgl_get_current_context = (CGLGetCurrentContextPtr)dlsym(library_handle, "CGLGetCurrentContext");
	cgl_tex_image_iosurface_2d = (CGLTexImageIOSurface2DPtr)dlsym(library_handle, "CGLTexImageIOSurface2D");
	cgl_error_string = (CGLErrorStringPtr)dlsym(library_handle, "CGLErrorString");
	framework_loaded = cgl_get_current_context && cgl_tex_image_iosurface_2d && cgl_error_string;
	ERR_FAIL_COND_V_MSG(!framework_loaded, ERR_CANT_CREATE, "Failed to load OpenGL IOSurface symbols.");

	return OK;
}
#endif

Error GLManagerApple::initialize(void *p_native_display) {
#if defined(IOS_ENABLED)
	// Create GL ES 3 context
	if (OS::get_singleton()->get_current_rendering_method() == "gl_compatibility" && context == nullptr) {
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
		ERR_FAIL_COND_V_MSG(!context, FAILED, "Failed to create OpenGL ES 3.0 context!");
	}

	if (![EAGLContext setCurrentContext:context]) {
		ERR_FAIL_V_MSG(FAILED, "Unable to set current EAGLContext");
	}
#elif defined(MACOS_ENABLED)
	if (OS::get_singleton()->get_current_rendering_method() == "gl_compatibility" && context == nullptr) {
		NSOpenGLPixelFormatAttribute attributes[] = {
			NSOpenGLPFADoubleBuffer,
			NSOpenGLPFAClosestPolicy,
			NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
			NSOpenGLPFAColorSize, 32,
			NSOpenGLPFADepthSize, 24,
			NSOpenGLPFAStencilSize, 8,
			0
		};

		NSOpenGLPixelFormat *pixel_format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
		ERR_FAIL_COND_V_MSG(!pixel_format, FAILED, "Failed to create NSOpenGLPixelFormat!");

		context = [[NSOpenGLContext alloc] initWithFormat:pixel_format shareContext:nil];
		ERR_FAIL_COND_V_MSG(!context, FAILED, "Failed to create NSOpenGLContext!");
	}

	Error framework_err = load_opengl_framework();
	ERR_FAIL_COND_V(framework_err != OK, framework_err);

	[context makeCurrentContext];
#endif
	return OK;
}

Size2i GLManagerApple::window_get_size(DisplayServerEnums::WindowID p_id) const {
	ERR_FAIL_COND_V(!windows.has(p_id), Size2i());
	const WindowData &gles_data = windows[p_id];
#if defined(MACOS_ENABLED)
	return Size2i(gles_data.backingWidth, gles_data.backingHeight);
#else
	return Size2i(gles_data.layer.bounds.size.width, gles_data.layer.bounds.size.height);
#endif
}

void GLManagerApple::window_resize(DisplayServerEnums::WindowID p_id, int p_width, int p_height) {
	ERR_FAIL_COND(!windows.has(p_id));
	WindowData &gles_data = windows[p_id];
#if defined(IOS_ENABLED)
	GL_ERR([EAGLContext setCurrentContext:context]);
	CAEAGLLayer *layer = gles_data.layer;
	window_destroy(p_id);
	create_framebuffer(p_id, (__bridge void *)layer, p_width, p_height);
#elif defined(MACOS_ENABLED)
	GL_ERR([context makeCurrentContext]);
	destroy_framebuffers(gles_data, false);
	Error err = create_framebuffer(p_id, (__bridge void *)gles_data.layer, p_width, p_height);
	ERR_FAIL_COND_MSG(err != OK, "Failed to resize macOS OpenGL framebuffer.");
#endif
}

void GLManagerApple::window_make_current(DisplayServerEnums::WindowID p_id) {
	ERR_FAIL_COND(!windows.has(p_id));
	WindowData &gles_data = windows[p_id];
#if defined(IOS_ENABLED)
	GL_ERR([EAGLContext setCurrentContext:context]);
	GL_ERR(glBindFramebufferOES(GL_FRAMEBUFFER_OES, gles_data.viewFramebuffer));
	current_window = p_id;
#elif defined(MACOS_ENABLED)
	GL_ERR([context makeCurrentContext]);
	if (gles_data.framebuffersValid) {
		GL_ERR(glBindFramebuffer(GL_FRAMEBUFFER, gles_data.viewFramebuffer));
	}
	current_window = p_id;
#endif
}

void GLManagerApple::swap_buffers() {
	ERR_FAIL_COND(!windows.has(current_window));
	WindowData &gles_data = windows[current_window];
#if defined(IOS_ENABLED)
	GL_ERR([EAGLContext setCurrentContext:context]);
	GL_ERR(glBindRenderbufferOES(GL_RENDERBUFFER_OES, gles_data.viewRenderbuffer));
	GL_ERR([context presentRenderbuffer:GL_RENDERBUFFER_OES]);
#elif defined(MACOS_ENABLED)
	GL_ERR([context makeCurrentContext]);
	if (gles_data.framebuffersValid) {
		GL_ERR(glBindFramebuffer(GL_FRAMEBUFFER, gles_data.viewFramebuffer));
	}
	[context flushBuffer];
	GL_ERR(glFlush());
	if (gles_data.framebuffersValid) {
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		gles_data.layer.contents = (__bridge id)gles_data.framebuffers[gles_data.currentFramebuffer].surface;
		[CATransaction commit];

		gles_data.currentFramebuffer = (gles_data.currentFramebuffer + 1) % MACOS_BUFFER_COUNT;
		gles_data.viewFramebuffer = gles_data.framebuffers[gles_data.currentFramebuffer].framebuffer;
		GL_ERR(glBindFramebuffer(GL_FRAMEBUFFER, gles_data.viewFramebuffer));
	}
#endif
}

void GLManagerApple::deinitialize() {
#if defined(IOS_ENABLED)
	if ([EAGLContext currentContext] == context) {
		[EAGLContext setCurrentContext:nil];
	}

	if (context) {
		context = nil;
	}
#elif defined(MACOS_ENABLED)
	if ([NSOpenGLContext currentContext] == context) {
		[NSOpenGLContext clearCurrentContext];
	}

	if (context) {
		[context clearDrawable];
		context = nil;
	}
#endif
}

Error GLManagerApple::window_create(DisplayServerEnums::WindowID p_id, Ref<RenderingNativeSurface> p_native_surface, int p_width, int p_height) {
#if defined(IOS_ENABLED)
	NSLog(@"GLESContextApple::create_framebuffer surface");
	CAEAGLLayer *layer = nullptr;
	Ref<RenderingNativeSurfaceApple> apple_surface = Object::cast_to<RenderingNativeSurfaceApple>(*p_native_surface);
	if (apple_surface.is_valid()) {
		layer = (__bridge CAEAGLLayer *)(void *)apple_surface->get_layer();
	}
	ERR_FAIL_COND_V_MSG(layer == nullptr, ERR_CANT_CREATE, "Unable to create GL window");

	return create_framebuffer(p_id, (__bridge void *)layer, p_width, p_height);
#elif defined(MACOS_ENABLED)
#ifdef GLES3_ENABLED
#ifdef GLAD_ENABLED
	RasterizerGLES3::preloadGL(nullptr);
#endif
#endif
	NSLog(@"GLESContextApple::create_framebuffer surface");
	CALayer *layer = nullptr;
	Ref<RenderingNativeSurfaceApple> apple_surface = Object::cast_to<RenderingNativeSurfaceApple>(*p_native_surface);
	if (apple_surface.is_valid()) {
		layer = (__bridge CALayer *)(void *)apple_surface->get_layer();
	}
	ERR_FAIL_COND_V_MSG(layer == nullptr, ERR_CANT_CREATE, "Unable to create GL window");

	return create_framebuffer(p_id, (__bridge void *)layer, p_width, p_height);
#else
	return FAILED;
#endif
}

Error GLManagerApple::create_framebuffer(DisplayServerEnums::WindowID p_id, void *p_layer, int p_width, int p_height) {
	WindowData &gles_data = windows[p_id];
#if defined(IOS_ENABLED)
	NSLog(@"GLESContextApple::create_framebuffer layer");
	GL_ERR([EAGLContext setCurrentContext:context]);
	gles_data.layer = (__bridge CAEAGLLayer *)p_layer;

	GL_ERR(glGenFramebuffersOES(1, &gles_data.viewFramebuffer));
	GL_ERR(glGenRenderbuffersOES(1, &gles_data.viewRenderbuffer));

	GL_ERR(glBindFramebufferOES(GL_FRAMEBUFFER_OES, gles_data.viewFramebuffer));
	GL_ERR(glBindRenderbufferOES(GL_RENDERBUFFER_OES, gles_data.viewRenderbuffer));
	// This call associates the storage for the current render buffer with the EAGLDrawable (our CAself)
	// allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
	[CATransaction flush];
	GL_ERR([context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:gles_data.layer]);
	GL_ERR(glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, gles_data.viewRenderbuffer));

	GL_ERR(glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &gles_data.backingWidth));
	GL_ERR(glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &gles_data.backingHeight));

	// For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
	GL_ERR(glGenRenderbuffersOES(1, &gles_data.depthRenderbuffer));
	GL_ERR(glBindRenderbufferOES(GL_RENDERBUFFER_OES, gles_data.depthRenderbuffer));
	GL_ERR(glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, gles_data.backingWidth, gles_data.backingHeight));
	GL_ERR(glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, gles_data.depthRenderbuffer));

	if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return FAILED;
	}

	return OK;
#elif defined(MACOS_ENABLED)
	NSLog(@"GLESContextApple::create_framebuffer layer");
	GL_ERR([context makeCurrentContext]);
	gles_data.layer = (__bridge CALayer *)p_layer;
	ERR_FAIL_NULL_V_MSG(gles_data.layer, ERR_CANT_CREATE, "Unable to create GL window from null layer.");
	gles_data.layer.contentsGravity = kCAGravityResize;
	gles_data.layer.magnificationFilter = kCAFilterNearest;
	gles_data.layer.minificationFilter = kCAFilterNearest;
	gles_data.layer.needsDisplayOnBoundsChange = NO;
	gles_data.layer.actions = @{ @"contents" : [NSNull null] };
	gles_data.framebuffersValid = false;

	gles_data.backingWidth = p_width;
	gles_data.backingHeight = p_height;
	if (gles_data.backingWidth <= 0 || gles_data.backingHeight <= 0) {
		CGFloat contents_scale = gles_data.layer.contentsScale > 0.0 ? gles_data.layer.contentsScale : 1.0;
		gles_data.backingWidth = (GLint)(gles_data.layer.bounds.size.width * contents_scale);
		gles_data.backingHeight = (GLint)(gles_data.layer.bounds.size.height * contents_scale);
	}
	if (gles_data.backingWidth <= 0) {
		gles_data.backingWidth = 1;
	}
	if (gles_data.backingHeight <= 0) {
		gles_data.backingHeight = 1;
	}
	GLint max_renderbuffer_size = 0;
	GL_ERR(glGetIntegerv(GL_MAX_RENDERBUFFER_SIZE, &max_renderbuffer_size));
	GLint max_backing_size = MIN(MACOS_MAX_BACKING_SIZE, max_renderbuffer_size);
	ERR_FAIL_COND_V_MSG(max_backing_size <= 0 || gles_data.backingWidth > max_backing_size || gles_data.backingHeight > max_backing_size, ERR_CANT_CREATE,
			vformat("Invalid macOS OpenGL framebuffer size: width=%d, height=%d, max=%d", gles_data.backingWidth, gles_data.backingHeight, max_backing_size));

	GL_ERR(glGenRenderbuffers(1, &gles_data.depthRenderbuffer));
	GL_ERR(glBindRenderbuffer(GL_RENDERBUFFER, gles_data.depthRenderbuffer));
	GL_ERR(glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, gles_data.backingWidth, gles_data.backingHeight));

	for (uint32_t i = 0; i < MACOS_BUFFER_COUNT; i++) {
		MacOSFrameBuffer &fb = gles_data.framebuffers[i];

		NSDictionary *surfaceProps = @{
			(NSString *)kIOSurfaceWidth : @(gles_data.backingWidth),
			(NSString *)kIOSurfaceHeight : @(gles_data.backingHeight),
			(NSString *)kIOSurfaceBytesPerElement : @(4),
			(NSString *)kIOSurfacePixelFormat : @(kCVPixelFormatType_32BGRA),
		};
		fb.surface = IOSurfaceCreate((__bridge CFDictionaryRef)surfaceProps);
		if (fb.surface == nullptr) {
			ERR_PRINT(vformat("Failed to create IOSurface: width=%d, height=%d", gles_data.backingWidth, gles_data.backingHeight));
			destroy_framebuffers(gles_data, false);
			return ERR_CANT_CREATE;
		}

		GL_ERR(glGenTextures(1, &fb.colorTexture));
		GL_ERR(glBindTexture(GL_TEXTURE_RECTANGLE, fb.colorTexture));
		GL_ERR(glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR));
		GL_ERR(glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR));
		GL_ERR(glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE));
		GL_ERR(glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE));

		CGLError cgl_err = cgl_tex_image_iosurface_2d(cgl_get_current_context(),
				GL_TEXTURE_RECTANGLE,
				GL_RGBA,
				gles_data.backingWidth,
				gles_data.backingHeight,
				GL_BGRA,
				GL_UNSIGNED_INT_8_8_8_8_REV,
				fb.surface,
				0);
		if (cgl_err != kCGLNoError) {
			String err_string = String(cgl_error_string(cgl_err));
			ERR_PRINT(vformat("CGLTexImageIOSurface2D failed (%d): %s", cgl_err, err_string));
			destroy_framebuffers(gles_data, false);
			return ERR_CANT_CREATE;
		}

		GL_ERR(glGenFramebuffers(1, &fb.framebuffer));
		GL_ERR(glBindFramebuffer(GL_FRAMEBUFFER, fb.framebuffer));
		GL_ERR(glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE, fb.colorTexture, 0));
		GL_ERR(glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, gles_data.depthRenderbuffer));

		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
			NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
			destroy_framebuffers(gles_data, false);
			return FAILED;
		}
	}

	gles_data.currentFramebuffer = 0;
	gles_data.framebuffersValid = true;
	gles_data.viewFramebuffer = gles_data.framebuffers[gles_data.currentFramebuffer].framebuffer;

	GL_ERR(glBindFramebuffer(GL_FRAMEBUFFER, gles_data.viewFramebuffer));
	GL_ERR(glBindTexture(GL_TEXTURE_RECTANGLE, 0));

	return OK;
#else
	return FAILED;
#endif
}

#if defined(MACOS_ENABLED)
void GLManagerApple::destroy_framebuffers(WindowData &p_gles_data, bool p_clear_layer_contents) {
	p_gles_data.framebuffersValid = false;
	p_gles_data.viewFramebuffer = 0;

	for (uint32_t i = 0; i < MACOS_BUFFER_COUNT; i++) {
		MacOSFrameBuffer &fb = p_gles_data.framebuffers[i];

		if (fb.framebuffer) {
			GL_ERR(glDeleteFramebuffers(1, &fb.framebuffer));
			fb.framebuffer = 0;
		}

		if (fb.colorTexture) {
			GL_ERR(glDeleteTextures(1, &fb.colorTexture));
			fb.colorTexture = 0;
		}

		if (fb.surface) {
			IOSurfaceRef old_surface = fb.surface;
			fb.surface = nullptr;
			CFRelease(old_surface);
		}
	}

	if (p_gles_data.depthRenderbuffer) {
		GL_ERR(glDeleteRenderbuffers(1, &p_gles_data.depthRenderbuffer));
		p_gles_data.depthRenderbuffer = 0;
	}

	if (p_clear_layer_contents && p_gles_data.layer) {
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		p_gles_data.layer.contents = nil;
		[CATransaction commit];
	}

	p_gles_data.currentFramebuffer = 0;
}
#endif

// Clean up any buffers we have allocated.
void GLManagerApple::window_destroy(DisplayServerEnums::WindowID p_id) {
	ERR_FAIL_COND(!windows.has(p_id));
	WindowData &gles_data = windows[p_id];
#if defined(IOS_ENABLED)
	GL_ERR([EAGLContext setCurrentContext:context]);
	GL_ERR(glDeleteFramebuffersOES(1, &gles_data.viewFramebuffer));
	gles_data.viewFramebuffer = 0;
	GL_ERR(glDeleteRenderbuffersOES(1, &gles_data.viewRenderbuffer));
	gles_data.viewRenderbuffer = 0;

	if (gles_data.depthRenderbuffer) {
		GL_ERR(glDeleteRenderbuffersOES(1, &gles_data.depthRenderbuffer));
		gles_data.depthRenderbuffer = 0;
	}
#elif defined(MACOS_ENABLED)
	GL_ERR([context makeCurrentContext]);
	destroy_framebuffers(gles_data, true);
#endif
	if (current_window == p_id) {
		current_window = DisplayServerEnums::INVALID_WINDOW_ID;
	}
	windows.erase(p_id);
}

int GLManagerApple::window_get_render_target(DisplayServerEnums::WindowID p_id) const {
	ERR_FAIL_COND_V(!windows.has(p_id), 0);
	const WindowData &gles_data = windows[p_id];
	return gles_data.viewFramebuffer;
}

#endif // GLES3_ENABLED

void RenderingNativeSurfaceApple::_bind_methods() {
	ClassDB::bind_static_method("RenderingNativeSurfaceApple", D_METHOD("create", "layer"), &RenderingNativeSurfaceApple::create_api);
	ClassDB::bind_method(D_METHOD("get_layer"), &RenderingNativeSurfaceApple::get_layer);
}

Ref<RenderingNativeSurfaceApple> RenderingNativeSurfaceApple::create_api(/* GDExtensionConstPtr<const void> */ uint64_t p_layer) {
	return RenderingNativeSurfaceApple::create((void *)p_layer /* .operator const void *() */);
}

Ref<RenderingNativeSurfaceApple> RenderingNativeSurfaceApple::create(void *p_layer) {
	Ref<RenderingNativeSurfaceApple> result;
	if (!p_layer) {
		String rendering_driver = OS::get_singleton()->get_current_rendering_driver_name();
		CALayer *__block myLayer = nil;
		dispatch_sync(dispatch_get_main_queue(), ^{
#if defined(GLES3_ENABLED)
			if (rendering_driver == "opengl3") {
#if defined(IOS_ENABLED)
				myLayer = [[CAEAGLLayer alloc] init];
#elif defined(MACOS_ENABLED)
				myLayer = [[CALayer alloc] init];
#endif
			}
#endif

			if (rendering_driver == "metal" || rendering_driver == "vulkan") {
				myLayer = [[CAMetalLayer alloc] init];
			}
		});
		if (!myLayer) {
			return result;
		}
		p_layer = (void *)CFBridgingRetain(myLayer);
	} else {
		p_layer = (void *)CFBridgingRetain((__bridge CALayer *)p_layer);
	}

	result.instantiate();
	result->layer = p_layer;
	return result;
}

uint64_t RenderingNativeSurfaceApple::get_layer() {
	return (uint64_t)layer;
}

void *RenderingNativeSurfaceApple::get_native_id() const {
	return (void *)layer;
}

RenderingContextDriver *RenderingNativeSurfaceApple::create_rendering_context(const String &p_rendering_driver) {
#if defined(VULKAN_ENABLED)
	if (p_rendering_driver == "vulkan") {
		return memnew(RenderingContextDriverVulkanApple);
	}
#endif
#if defined(METAL_ENABLED)
	if (p_rendering_driver == "metal") {
		if (@available(ios 14.0, *)) {
			return memnew(RenderingContextDriverMetal);
		}
	}
#endif
	return nullptr;
}

GLManager *RenderingNativeSurfaceApple::create_gl_manager(const String &p_driver_name) {
#if defined(GLES3_ENABLED)
#if defined(EGL_STATIC)
	if (p_driver_name == "opengl3_angle") {
		return memnew(GLManagerANGLE_Embedded);
	}
#endif
#if defined(ANGLE_ENABLED)
	if (p_driver_name == "opengl3_angle") {
#if defined(IOS_ENABLED) && defined(GLAD_ENABLED)
		static CharString libegl_framework_path = OS_IOS::get_singleton()->get_library_path("libEGL.framework").utf8();
		static CharString libglesv2_framework_path = OS_IOS::get_singleton()->get_library_path("libGLESv2.framework").utf8();
		const char *eg = libegl_framework_path.get_data();
		const char *gl = libglesv2_framework_path.get_data();
		gladSetupEGL(1, &eg);
		gladSetupGLES2(1, &gl);
#endif
		return memnew(GLManagerANGLE_Embedded);
	}
#endif
	if (p_driver_name == "opengl3") {
		return memnew(GLManagerApple);
	}
#endif
	return nullptr;
}

RenderingNativeSurfaceApple::RenderingNativeSurfaceApple() {
}

RenderingNativeSurfaceApple::~RenderingNativeSurfaceApple() {
	if (layer) {
		CFBridgingRelease(layer);
	}
}
