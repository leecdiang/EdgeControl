#ifndef ECPrivateAPIBridge_h
#define ECPrivateAPIBridge_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ECMultitouchHandle ECMultitouchHandle;

enum {
    EC_TRACKPAD_SELECTION_AUTO = 0,
    EC_TRACKPAD_SELECTION_BUILT_IN = 1,
    EC_TRACKPAD_SELECTION_EXTERNAL = 2
};

enum {
    EC_TRACKPAD_KIND_UNKNOWN = 0,
    EC_TRACKPAD_KIND_BUILT_IN = 1,
    EC_TRACKPAD_KIND_EXTERNAL = 2
};

typedef struct {
    int32_t identifier;
    double x;
    double y;
    int32_t raw_state;
    float size;
} ECTouchContactRaw;

typedef void (*ECTouchFrameCallback)(
    void *context,
    const ECTouchContactRaw *contacts,
    size_t contact_count,
    double timestamp
);

/// LOCAL_VALIDATION_REQUIRED: MultitouchSupport ABI and contact layout.
ECMultitouchHandle *ec_mt_open(
    int32_t selection,
    ECTouchFrameCallback callback,
    void *context,
    int32_t *selected_kind
);
void ec_mt_close(ECMultitouchHandle *handle);
bool ec_mt_is_available(void);
/// Pure geometry guard used to reject portrait-oriented external devices.
bool ec_mt_surface_dimensions_look_like_trackpad(int32_t width, int32_t height);

/// Private actuator calls stay disabled unless explicitly enabled for local ABI work.
bool ec_mt_private_haptic_is_available(void);
bool ec_mt_private_haptic_pulse(int32_t pattern);
void ec_mt_private_haptic_reset(void);

/// Runtime-loaded DisplayServices bridge. No private framework is hard-linked.
bool ec_display_services_is_available(void);
bool ec_display_services_get_brightness(uint32_t display_id, float *brightness);
bool ec_display_services_set_brightness(uint32_t display_id, float brightness);

typedef struct ECDDCHandle ECDDCHandle;

/// Legacy framebuffer I2C DDC/CI transport. It fails closed on unsupported Macs.
ECDDCHandle *ec_ddc_open(uint32_t display_id);
void ec_ddc_close(ECDDCHandle *handle);
bool ec_ddc_get_vcp10(ECDDCHandle *handle, uint16_t *current_value, uint16_t *maximum_value);
bool ec_ddc_parse_vcp10_reply(const uint8_t *reply, size_t reply_count, uint16_t *current_value, uint16_t *maximum_value);
bool ec_ddc_set_vcp10(ECDDCHandle *handle, uint16_t value);

#ifdef __cplusplus
}
#endif

#endif
