/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2025 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/

#include "SDL_internal.h"

#if defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_TVOS)

#define hid_close                    PLATFORM_hid_close
#define hid_device                   PLATFORM_hid_device
#define hid_device_                  PLATFORM_hid_device_
#define hid_enumerate                PLATFORM_hid_enumerate
#define hid_error                    PLATFORM_hid_error
#define hid_exit                     PLATFORM_hid_exit
#define hid_free_enumeration         PLATFORM_hid_free_enumeration
#define hid_get_device_info          PLATFORM_hid_get_device_info
#define hid_get_feature_report       PLATFORM_hid_get_feature_report
#define hid_get_indexed_string       PLATFORM_hid_get_indexed_string
#define hid_get_input_report         PLATFORM_hid_get_input_report
#define hid_get_manufacturer_string  PLATFORM_hid_get_manufacturer_string
#define hid_get_product_string       PLATFORM_hid_get_product_string
#define hid_get_report_descriptor    PLATFORM_hid_get_report_descriptor
#define hid_get_serial_number_string PLATFORM_hid_get_serial_number_string
#define hid_init                     PLATFORM_hid_init
#define hid_open_path                PLATFORM_hid_open_path
#define hid_open                     PLATFORM_hid_open
#define hid_read                     PLATFORM_hid_read
#define hid_read_timeout             PLATFORM_hid_read_timeout
#define hid_send_feature_report      PLATFORM_hid_send_feature_report
#define hid_set_nonblocking          PLATFORM_hid_set_nonblocking
#define hid_version                  PLATFORM_hid_version
#define hid_version_str              PLATFORM_hid_version_str
#define hid_write                    PLATFORM_hid_write

#include "../hidapi/hidapi.h"

struct hid_device_ {
	int unused;
};

int HID_API_EXPORT HID_API_CALL hid_init(void) {
	return 0;
}

int HID_API_EXPORT HID_API_CALL hid_exit(void) {
	return 0;
}

struct hid_device_info HID_API_EXPORT *HID_API_CALL hid_enumerate(unsigned short p_vendor_id, unsigned short p_product_id) {
	(void)p_vendor_id;
	(void)p_product_id;
	return NULL;
}

void HID_API_EXPORT HID_API_CALL hid_free_enumeration(struct hid_device_info *p_devs) {
	(void)p_devs;
}

HID_API_EXPORT hid_device *HID_API_CALL hid_open(unsigned short p_vendor_id, unsigned short p_product_id, const wchar_t *p_serial_number) {
	(void)p_vendor_id;
	(void)p_product_id;
	(void)p_serial_number;
	return NULL;
}

HID_API_EXPORT hid_device *HID_API_CALL hid_open_path(const char *p_path) {
	(void)p_path;
	return NULL;
}

int HID_API_EXPORT HID_API_CALL hid_write(hid_device *p_dev, const unsigned char *p_data, size_t p_length) {
	(void)p_dev;
	(void)p_data;
	(void)p_length;
	return -1;
}

int HID_API_EXPORT HID_API_CALL hid_read_timeout(hid_device *p_dev, unsigned char *p_data, size_t p_length, int p_milliseconds) {
	(void)p_dev;
	(void)p_data;
	(void)p_length;
	(void)p_milliseconds;
	return -1;
}

int HID_API_EXPORT HID_API_CALL hid_read(hid_device *p_dev, unsigned char *p_data, size_t p_length) {
	return hid_read_timeout(p_dev, p_data, p_length, 0);
}

int HID_API_EXPORT HID_API_CALL hid_set_nonblocking(hid_device *p_dev, int p_nonblock) {
	(void)p_dev;
	(void)p_nonblock;
	return -1;
}

int HID_API_EXPORT HID_API_CALL hid_send_feature_report(hid_device *p_dev, const unsigned char *p_data, size_t p_length) {
	(void)p_dev;
	(void)p_data;
	(void)p_length;
	return -1;
}

int HID_API_EXPORT HID_API_CALL hid_get_feature_report(hid_device *p_dev, unsigned char *p_data, size_t p_length) {
	(void)p_dev;
	(void)p_data;
	(void)p_length;
	return -1;
}

int HID_API_EXPORT HID_API_CALL hid_get_input_report(hid_device *p_dev, unsigned char *p_data, size_t p_length) {
	(void)p_dev;
	(void)p_data;
	(void)p_length;
	return -1;
}

void HID_API_EXPORT HID_API_CALL hid_close(hid_device *p_dev) {
	(void)p_dev;
}

int HID_API_EXPORT_CALL hid_get_manufacturer_string(hid_device *p_dev, wchar_t *p_string, size_t p_maxlen) {
	(void)p_dev;
	(void)p_string;
	(void)p_maxlen;
	return -1;
}

int HID_API_EXPORT_CALL hid_get_product_string(hid_device *p_dev, wchar_t *p_string, size_t p_maxlen) {
	(void)p_dev;
	(void)p_string;
	(void)p_maxlen;
	return -1;
}

int HID_API_EXPORT_CALL hid_get_serial_number_string(hid_device *p_dev, wchar_t *p_string, size_t p_maxlen) {
	(void)p_dev;
	(void)p_string;
	(void)p_maxlen;
	return -1;
}

struct hid_device_info HID_API_EXPORT *HID_API_CALL hid_get_device_info(hid_device *p_dev) {
	(void)p_dev;
	return NULL;
}

int HID_API_EXPORT_CALL hid_get_indexed_string(hid_device *p_dev, int p_string_index, wchar_t *p_string, size_t p_maxlen) {
	(void)p_dev;
	(void)p_string_index;
	(void)p_string;
	(void)p_maxlen;
	return -1;
}

int HID_API_EXPORT_CALL hid_get_report_descriptor(hid_device *p_dev, unsigned char *p_buf, size_t p_buf_size) {
	(void)p_dev;
	(void)p_buf;
	(void)p_buf_size;
	return -1;
}

HID_API_EXPORT const wchar_t *HID_API_CALL hid_error(hid_device *p_dev) {
	(void)p_dev;
	return L"iOS HIDAPI backend is unavailable";
}

HID_API_EXPORT const struct hid_api_version *HID_API_CALL hid_version(void) {
	static const struct hid_api_version version = { HID_API_VERSION_MAJOR, HID_API_VERSION_MINOR, HID_API_VERSION_PATCH };
	return &version;
}

HID_API_EXPORT const char *HID_API_CALL hid_version_str(void) {
	return HID_API_VERSION_STR;
}

void hid_ble_scan(int p_start) {
	(void)p_start;
}

#endif // SDL_PLATFORM_IOS || SDL_PLATFORM_TVOS
