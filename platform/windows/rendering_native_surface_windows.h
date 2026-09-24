/**************************************************************************/
/*  rendering_native_surface_windows.h                                    */
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

#include "core/os/mutex.h"
#include "core/variant/callable.h"
#include "core/variant/native_ptr.h"
#include "servers/rendering/rendering_native_surface.h"

#include <atomic>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

class RenderingNativeSurfaceWindows : public RenderingNativeSurface {
public:
private:
	GDCLASS(RenderingNativeSurfaceWindows, RenderingNativeSurface);

	static void _bind_methods();

	HWND window;
	HINSTANCE instance;
	uint32_t width;
	uint32_t height;
	std::atomic<uint64_t> swap_chain_ptr{ 0 };
	std::atomic<uint64_t> swap_chain_generation{ 0 };
	Callable swap_chain_changed_callback;
	mutable Mutex swap_chain_changed_callback_mutex;

public:
	static Ref<RenderingNativeSurfaceWindows> create_api(GDExtensionConstPtr<const void> p_window, GDExtensionConstPtr<const void> p_instance);

	static Ref<RenderingNativeSurfaceWindows> create(HWND p_window, HINSTANCE p_instance);

	HWND get_window_handle() const {
		return window;
	}

	HINSTANCE get_instance() const {
		return instance;
	}

	uint64_t get_swap_chain_ptr() const {
		return swap_chain_ptr.load();
	}

	uint64_t get_swap_chain_generation() const {
		return swap_chain_generation.load();
	}

	void set_swap_chain_changed_callback(const Callable &p_callback);

	bool uses_swap_chain_panel() const {
		return window == nullptr;
	}

	void set_swap_chain_ptr(uint64_t p_swap_chain_ptr) {
		const uint64_t previous_swap_chain_ptr = swap_chain_ptr.exchange(p_swap_chain_ptr);
		uint64_t current_generation = swap_chain_generation.load();
		if (previous_swap_chain_ptr != p_swap_chain_ptr) {
			current_generation = swap_chain_generation.fetch_add(1) + 1;
		}

		Callable callback;
		{
			MutexLock lock(swap_chain_changed_callback_mutex);
			callback = swap_chain_changed_callback;
		}

		if (callback.is_valid()) {
			callback.call(p_swap_chain_ptr, current_generation);
		}
	}

	RenderingContextDriver *create_rendering_context(const String &p_driver_name) override;

	void *get_native_id() const override;

	uint32_t get_width() const {
		return width;
	}

	uint32_t get_height() const {
		return height;
	}

	RenderingNativeSurfaceWindows();
	~RenderingNativeSurfaceWindows();
};
