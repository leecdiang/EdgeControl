#include "ECPrivateAPIBridge.h"

#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if __has_include(<IOKit/IOKitLib.h>) && \
    __has_include(<IOKit/graphics/IOGraphicsLib.h>) && \
    __has_include(<IOKit/i2c/IOI2CInterface.h>)
#define EC_HAS_LEGACY_DDC 1
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <IOKit/i2c/IOI2CInterface.h>
#include <mach/mach.h>
#include <unistd.h>
#else
#define EC_HAS_LEGACY_DDC 0
#endif

// MARK: - MultitouchSupport

typedef struct {
    float x;
    float y;
} ECMTPoint;

/// Observed on macOS 26.5 (arm64): stride is 96 bytes. The first 80 bytes match
/// the commonly observed layout; the final 16 bytes were verified as zero-padding
/// on this machine (ECProbe raw dump, 2026-08-16). LOCAL_VALIDATION_REQUIRED on
/// every supported macOS/architecture combination.
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier;
    int32_t state;
    int32_t finger_number;
    int32_t unknown1;
    ECMTPoint normalized;
    float size;
    int32_t unknown2;
    float angle;
    float major_axis;
    float minor_axis;
    ECMTPoint absolute;
    int32_t unknown3[2];
    float density;
    int32_t unknown4[4];
} ECMTFingerABI;

typedef void *(*ECMTDeviceCreateDefaultFn)(void);
// LOCAL_VALIDATION_REQUIRED: these three enumeration/metadata signatures are
// private ABI and must be rechecked on every supported macOS/architecture.
typedef CFArrayRef (*ECMTDeviceCreateListFn)(void);
typedef bool (*ECMTDeviceIsBuiltInFn)(void *);
typedef int32_t (*ECMTDeviceGetSensorSurfaceDimensionsFn)(void *, int32_t *, int32_t *);
typedef void (*ECMTRegisterFrameCallbackFn)(void *, void *);
typedef void (*ECMTUnregisterFrameCallbackFn)(void *, void *);
typedef void (*ECMTDeviceStartFn)(void *, int32_t);
typedef void (*ECMTDeviceStopFn)(void *);
typedef void (*ECMTDeviceReleaseFn)(void *);
typedef int32_t (*ECMTSystemFrameCallback)(
    void *device,
    ECMTFingerABI *contacts,
    int32_t contact_count,
    double timestamp,
    int32_t frame
);

struct ECMultitouchHandle {
    void *framework;
    void *device;
    CFArrayRef device_list;
    int32_t selected_kind;
    int32_t sensor_width;
    int32_t sensor_height;
    ECTouchFrameCallback callback;
    void *context;
    ECMTUnregisterFrameCallbackFn unregister_callback;
    ECMTDeviceStopFn stop;
    ECMTDeviceReleaseFn release;
    bool closing;
    size_t callbacks_in_flight;
};

static const char *kECMTPath =
    "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport";
static pthread_mutex_t g_mt_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_mt_condition = PTHREAD_COND_INITIALIZER;
static ECMultitouchHandle *g_mt_active_handle = NULL;

static int32_t ec_mt_system_callback(
    void *device,
    ECMTFingerABI *contacts,
    int32_t contact_count,
    double timestamp,
    int32_t frame
) {
    (void)device;
    (void)frame;

    pthread_mutex_lock(&g_mt_lock);
    ECMultitouchHandle *handle = g_mt_active_handle;
    if (handle == NULL || handle->closing || handle->callback == NULL) {
        pthread_mutex_unlock(&g_mt_lock);
        return 0;
    }
    handle->callbacks_in_flight += 1;
    ECTouchFrameCallback callback = handle->callback;
    void *context = handle->context;
    pthread_mutex_unlock(&g_mt_lock);

    size_t count = contact_count > 0 ? (size_t)contact_count : 0;

    // Debug-only ABI probe: Release compilation excludes this entire block.
#if defined(EDGE_DEBUG_LOGGING) && EDGE_DEBUG_LOGGING
    const char *dump_enabled = getenv("EDGE_RAW_DUMP");
    if (dump_enabled != NULL && strcmp(dump_enabled, "1") == 0 && count > 0) {
        fprintf(stderr, "[ECProbe] count=%d timestamp=%.3f frame=%d\n",
                contact_count, timestamp, frame);
        size_t dump_bytes = (size_t)contact_count * 96;
        if (dump_bytes > 384) {
            dump_bytes = 384;
        }
        const uint8_t *raw = (const uint8_t *)(const void *)contacts;
        for (size_t offset = 0; offset < dump_bytes; offset += 16) {
            fprintf(stderr, "[ECProbe] %04zx: ", offset);
            for (size_t column = 0; column < 16 && offset + column < dump_bytes; column += 1) {
                fprintf(stderr, "%02x ", raw[offset + column]);
            }
            fprintf(stderr, "\n");
        }
    }
#endif

    ECTouchContactRaw *translated = NULL;
    if (count > 0) {
        translated = calloc(count, sizeof(ECTouchContactRaw));
    }

    if (count == 0 || translated != NULL) {
        for (size_t index = 0; index < count; index += 1) {
            translated[index].identifier = contacts[index].identifier;
            translated[index].x = contacts[index].normalized.x;
            translated[index].y = contacts[index].normalized.y;
            translated[index].raw_state = contacts[index].state;
            translated[index].size = contacts[index].size;
        }
        callback(context, translated, count, timestamp);
    }
    free(translated);

    pthread_mutex_lock(&g_mt_lock);
    handle->callbacks_in_flight -= 1;
    if (handle->closing && handle->callbacks_in_flight == 0) {
        pthread_cond_signal(&g_mt_condition);
    }
    pthread_mutex_unlock(&g_mt_lock);
    return 0;
}

bool ec_mt_is_available(void) {
    void *framework = dlopen(kECMTPath, RTLD_LAZY | RTLD_LOCAL);
    if (framework == NULL) {
        return false;
    }
    bool available = dlsym(framework, "MTDeviceCreateDefault") != NULL &&
        dlsym(framework, "MTRegisterContactFrameCallback") != NULL &&
        dlsym(framework, "MTDeviceStart") != NULL &&
        dlsym(framework, "MTDeviceStop") != NULL;
    dlclose(framework);
    return available;
}

static void ec_mt_release_default_device(void *device, ECMTDeviceReleaseFn release) {
    if (device != NULL && release != NULL) {
        release(device);
    }
}

static bool ec_mt_read_surface_dimensions(
    void *device,
    ECMTDeviceGetSensorSurfaceDimensionsFn get_dimensions,
    int32_t *width,
    int32_t *height
) {
    if (device == NULL || get_dimensions == NULL || width == NULL || height == NULL) {
        return false;
    }
    *width = 0;
    *height = 0;
    return get_dimensions(device, width, height) == 0 && *width > 0 && *height > 0;
}

bool ec_mt_surface_dimensions_look_like_trackpad(int32_t width, int32_t height) {
    return width > 0 && height > 0 && width > height;
}

/// Magic Mouse surfaces observed by existing MultitouchSupport clients are
/// portrait-oriented, while built-in and Magic Trackpad surfaces are
/// landscape-oriented. Explicit external selection therefore fails closed
/// unless the device is non-built-in and reports width > height. Revalidate
/// this heuristic on every external Trackpad generation.
/// LOCAL_VALIDATION_REQUIRED: confirm Magic Mouse rejection and every supported
/// Magic Trackpad generation with the Debug selection probe.
static bool ec_mt_is_external_trackpad(
    void *device,
    ECMTDeviceIsBuiltInFn is_built_in,
    ECMTDeviceGetSensorSurfaceDimensionsFn get_dimensions,
    int32_t *width,
    int32_t *height
) {
    if (device == NULL || is_built_in == NULL || is_built_in(device)) {
        return false;
    }
    return ec_mt_read_surface_dimensions(device, get_dimensions, width, height) &&
        ec_mt_surface_dimensions_look_like_trackpad(*width, *height);
}

static void *ec_mt_select_from_list(
    CFArrayRef devices,
    int32_t selection,
    ECMTDeviceIsBuiltInFn is_built_in,
    ECMTDeviceGetSensorSurfaceDimensionsFn get_dimensions,
    int32_t *selected_kind,
    int32_t *sensor_width,
    int32_t *sensor_height
) {
    if (devices == NULL || is_built_in == NULL) {
        return NULL;
    }

    CFIndex count = CFArrayGetCount(devices);
    for (CFIndex index = 0; index < count; index += 1) {
        void *device = (void *)CFArrayGetValueAtIndex(devices, index);
        if (device == NULL) {
            continue;
        }

        if (selection == EC_TRACKPAD_SELECTION_BUILT_IN && is_built_in(device)) {
            if (selected_kind != NULL) {
                *selected_kind = EC_TRACKPAD_KIND_BUILT_IN;
            }
            (void)ec_mt_read_surface_dimensions(
                device,
                get_dimensions,
                sensor_width,
                sensor_height
            );
            return device;
        }

        int32_t width = 0;
        int32_t height = 0;
        if (selection == EC_TRACKPAD_SELECTION_EXTERNAL &&
            ec_mt_is_external_trackpad(
                device,
                is_built_in,
                get_dimensions,
                &width,
                &height
            )) {
            if (selected_kind != NULL) {
                *selected_kind = EC_TRACKPAD_KIND_EXTERNAL;
            }
            if (sensor_width != NULL) {
                *sensor_width = width;
            }
            if (sensor_height != NULL) {
                *sensor_height = height;
            }
            return device;
        }
    }
    return NULL;
}

ECMultitouchHandle *ec_mt_open(
    int32_t selection,
    ECTouchFrameCallback callback,
    void *context,
    int32_t *selected_kind
) {
    if (callback == NULL) {
        return NULL;
    }

    if (selection != EC_TRACKPAD_SELECTION_AUTO &&
        selection != EC_TRACKPAD_SELECTION_BUILT_IN &&
        selection != EC_TRACKPAD_SELECTION_EXTERNAL) {
        return NULL;
    }

    if (selected_kind != NULL) {
        *selected_kind = EC_TRACKPAD_KIND_UNKNOWN;
    }

    pthread_mutex_lock(&g_mt_lock);
    bool already_open = g_mt_active_handle != NULL;
    pthread_mutex_unlock(&g_mt_lock);
    if (already_open) {
        return NULL;
    }

    void *framework = dlopen(kECMTPath, RTLD_LAZY | RTLD_LOCAL);
    if (framework == NULL) {
        return NULL;
    }

    ECMTDeviceCreateDefaultFn create_device =
        (ECMTDeviceCreateDefaultFn)dlsym(framework, "MTDeviceCreateDefault");
    ECMTDeviceCreateListFn create_device_list =
        (ECMTDeviceCreateListFn)dlsym(framework, "MTDeviceCreateList");
    ECMTDeviceIsBuiltInFn is_built_in =
        (ECMTDeviceIsBuiltInFn)dlsym(framework, "MTDeviceIsBuiltIn");
    ECMTDeviceGetSensorSurfaceDimensionsFn get_dimensions =
        (ECMTDeviceGetSensorSurfaceDimensionsFn)dlsym(
            framework,
            "MTDeviceGetSensorSurfaceDimensions"
        );
    ECMTRegisterFrameCallbackFn register_callback =
        (ECMTRegisterFrameCallbackFn)dlsym(framework, "MTRegisterContactFrameCallback");
    ECMTUnregisterFrameCallbackFn unregister_callback =
        (ECMTUnregisterFrameCallbackFn)dlsym(framework, "MTUnregisterContactFrameCallback");
    ECMTDeviceStartFn start = (ECMTDeviceStartFn)dlsym(framework, "MTDeviceStart");
    ECMTDeviceStopFn stop = (ECMTDeviceStopFn)dlsym(framework, "MTDeviceStop");
    ECMTDeviceReleaseFn release = (ECMTDeviceReleaseFn)dlsym(framework, "MTDeviceRelease");

    if (create_device == NULL || register_callback == NULL || start == NULL || stop == NULL) {
        dlclose(framework);
        return NULL;
    }

    void *device = NULL;
    CFArrayRef device_list = NULL;
    int32_t resolved_kind = EC_TRACKPAD_KIND_UNKNOWN;
    int32_t sensor_width = 0;
    int32_t sensor_height = 0;

    if (selection == EC_TRACKPAD_SELECTION_AUTO) {
        // Preserve the 1.2.x default-device behavior exactly. Classification is
        // informational only; automatic mode must keep working if enumeration
        // or metadata symbols disappear on a future macOS release.
        device = create_device();
        if (device != NULL && is_built_in != NULL) {
            if (is_built_in(device)) {
                resolved_kind = EC_TRACKPAD_KIND_BUILT_IN;
            } else if (ec_mt_is_external_trackpad(
                device,
                is_built_in,
                get_dimensions,
                &sensor_width,
                &sensor_height
            )) {
                resolved_kind = EC_TRACKPAD_KIND_EXTERNAL;
            }
        }
        if (device != NULL && sensor_width == 0 && sensor_height == 0) {
            (void)ec_mt_read_surface_dimensions(
                device,
                get_dimensions,
                &sensor_width,
                &sensor_height
            );
        }
    } else if (selection == EC_TRACKPAD_SELECTION_BUILT_IN && is_built_in != NULL) {
        // Prefer the system default when it is built in. This avoids assuming
        // that the first built-in list entry is the trackpad on Touch Bar Macs.
        device = create_device();
        if (device != NULL && is_built_in(device)) {
            resolved_kind = EC_TRACKPAD_KIND_BUILT_IN;
            (void)ec_mt_read_surface_dimensions(
                device,
                get_dimensions,
                &sensor_width,
                &sensor_height
            );
        } else {
            ec_mt_release_default_device(device, release);
            device = NULL;
            if (create_device_list != NULL) {
                device_list = create_device_list();
                device = ec_mt_select_from_list(
                    device_list,
                    selection,
                    is_built_in,
                    get_dimensions,
                    &resolved_kind,
                    &sensor_width,
                    &sensor_height
                );
            }
        }
    } else if (selection == EC_TRACKPAD_SELECTION_EXTERNAL &&
               create_device_list != NULL && is_built_in != NULL) {
        device_list = create_device_list();
        device = ec_mt_select_from_list(
            device_list,
            selection,
            is_built_in,
            get_dimensions,
            &resolved_kind,
            &sensor_width,
            &sensor_height
        );
    }

    if (device == NULL) {
        if (device_list != NULL) {
            CFRelease(device_list);
        }
        dlclose(framework);
        return NULL;
    }

    ECMultitouchHandle *handle = calloc(1, sizeof(ECMultitouchHandle));
    if (handle == NULL) {
        if (device_list != NULL) {
            CFRelease(device_list);
        } else {
            ec_mt_release_default_device(device, release);
        }
        dlclose(framework);
        return NULL;
    }

    handle->framework = framework;
    handle->device = device;
    handle->device_list = device_list;
    handle->selected_kind = resolved_kind;
    handle->sensor_width = sensor_width;
    handle->sensor_height = sensor_height;
    handle->callback = callback;
    handle->context = context;
    handle->unregister_callback = unregister_callback;
    handle->stop = stop;
    handle->release = release;

    pthread_mutex_lock(&g_mt_lock);
    g_mt_active_handle = handle;
    pthread_mutex_unlock(&g_mt_lock);

    // Function-pointer cast is isolated here because the private callback ABI is
    // not represented by a public SDK header. LOCAL_VALIDATION_REQUIRED.
    register_callback(device, (void *)(ECMTSystemFrameCallback)ec_mt_system_callback);
    start(device, 0);

    if (selected_kind != NULL) {
        *selected_kind = resolved_kind;
    }

#if defined(EDGE_DEBUG_LOGGING) && EDGE_DEBUG_LOGGING
    fprintf(
        stderr,
        "[ECProbe] selected trackpad kind=%d surface=%dx%d selection=%d\n",
        resolved_kind,
        sensor_width,
        sensor_height,
        selection
    );
#endif
    return handle;
}

void ec_mt_close(ECMultitouchHandle *handle) {
    if (handle == NULL) {
        return;
    }

    pthread_mutex_lock(&g_mt_lock);
    handle->closing = true;
    pthread_mutex_unlock(&g_mt_lock);

    if (handle->stop != NULL) {
        handle->stop(handle->device);
    }
    if (handle->unregister_callback != NULL) {
        handle->unregister_callback(
            handle->device,
            (void *)(ECMTSystemFrameCallback)ec_mt_system_callback
        );
    }

    pthread_mutex_lock(&g_mt_lock);
    if (g_mt_active_handle == handle) {
        g_mt_active_handle = NULL;
    }
    while (handle->callbacks_in_flight > 0) {
        pthread_cond_wait(&g_mt_condition, &g_mt_lock);
    }
    pthread_mutex_unlock(&g_mt_lock);

    if (handle->device_list != NULL) {
        CFRelease(handle->device_list);
    } else if (handle->release != NULL) {
        handle->release(handle->device);
    }
    if (handle->framework != NULL) {
        dlclose(handle->framework);
    }
    free(handle);
}

// MARK: - Private trackpad actuator

// LOCAL_VALIDATION_REQUIRED: actuator signatures, ownership, and pattern values.

typedef void *(*ECMTActuatorCreateFn)(void *device);
typedef int32_t (*ECMTActuatorOpenFn)(void *actuator);
typedef int32_t (*ECMTActuatorActuateFn)(void *actuator, int32_t pattern);
typedef int32_t (*ECMTActuatorCloseFn)(void *actuator);

static void *g_actuator = NULL;

bool ec_mt_private_haptic_is_available(void) {
    const char *enabled = getenv("EDGE_ENABLE_UNVALIDATED_PRIVATE_HAPTIC");
    if (enabled == NULL || strcmp(enabled, "1") != 0) {
        return false;
    }

    pthread_mutex_lock(&g_mt_lock);
    ECMultitouchHandle *handle = g_mt_active_handle;
    bool available = handle != NULL &&
        dlsym(handle->framework, "MTActuatorCreateFromDevice") != NULL &&
        dlsym(handle->framework, "MTActuatorOpen") != NULL &&
        dlsym(handle->framework, "MTActuatorActuate") != NULL;
    pthread_mutex_unlock(&g_mt_lock);
    return available;
}

bool ec_mt_private_haptic_pulse(int32_t pattern) {
    if (!ec_mt_private_haptic_is_available()) {
        return false;
    }

    pthread_mutex_lock(&g_mt_lock);
    ECMultitouchHandle *handle = g_mt_active_handle;
    if (handle == NULL || handle->closing) {
        pthread_mutex_unlock(&g_mt_lock);
        return false;
    }
    ECMTActuatorCreateFn create =
        (ECMTActuatorCreateFn)dlsym(handle->framework, "MTActuatorCreateFromDevice");
    ECMTActuatorOpenFn open =
        (ECMTActuatorOpenFn)dlsym(handle->framework, "MTActuatorOpen");
    ECMTActuatorActuateFn actuate =
        (ECMTActuatorActuateFn)dlsym(handle->framework, "MTActuatorActuate");
    if (g_actuator == NULL && create != NULL && open != NULL) {
        g_actuator = create(handle->device);
        if (g_actuator != NULL && open(g_actuator) != 0) {
            g_actuator = NULL;
        }
    }
    bool succeeded = g_actuator != NULL && actuate != NULL && actuate(g_actuator, pattern) == 0;
    pthread_mutex_unlock(&g_mt_lock);
    return succeeded;
}

void ec_mt_private_haptic_reset(void) {
    pthread_mutex_lock(&g_mt_lock);
    ECMultitouchHandle *handle = g_mt_active_handle;
    if (g_actuator != NULL && handle != NULL) {
        ECMTActuatorCloseFn close_actuator =
            (ECMTActuatorCloseFn)dlsym(handle->framework, "MTActuatorClose");
        if (close_actuator != NULL) {
            close_actuator(g_actuator);
        }
    }
    g_actuator = NULL;
    pthread_mutex_unlock(&g_mt_lock);
}

// MARK: - DisplayServices

// LOCAL_VALIDATION_REQUIRED: symbol signatures and return-value semantics.

typedef int32_t (*ECDisplayGetBrightnessFn)(uint32_t display_id, float *brightness);
typedef int32_t (*ECDisplaySetBrightnessFn)(uint32_t display_id, float brightness);

static const char *kECDisplayServicesPath =
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices";

static void *ec_display_services_open(void) {
    return dlopen(kECDisplayServicesPath, RTLD_LAZY | RTLD_LOCAL);
}

bool ec_display_services_is_available(void) {
    void *framework = ec_display_services_open();
    if (framework == NULL) {
        return false;
    }
    bool available = dlsym(framework, "DisplayServicesGetBrightness") != NULL &&
        dlsym(framework, "DisplayServicesSetBrightness") != NULL;
    dlclose(framework);
    return available;
}

bool ec_display_services_get_brightness(uint32_t display_id, float *brightness) {
    if (brightness == NULL) {
        return false;
    }
    void *framework = ec_display_services_open();
    if (framework == NULL) {
        return false;
    }
    ECDisplayGetBrightnessFn get_brightness =
        (ECDisplayGetBrightnessFn)dlsym(framework, "DisplayServicesGetBrightness");
    bool succeeded = get_brightness != NULL && get_brightness(display_id, brightness) == 0;
    dlclose(framework);
    return succeeded;
}

bool ec_display_services_set_brightness(uint32_t display_id, float brightness) {
    void *framework = ec_display_services_open();
    if (framework == NULL) {
        return false;
    }
    ECDisplaySetBrightnessFn set_brightness =
        (ECDisplaySetBrightnessFn)dlsym(framework, "DisplayServicesSetBrightness");
    bool succeeded = set_brightness != NULL && set_brightness(display_id, brightness) == 0;
    dlclose(framework);
    return succeeded;
}

// MARK: - DDC/CI VCP 0x10

// LOCAL_VALIDATION_REQUIRED: I2C addressing, timing, reply layout, and hardware support.

struct ECDDCHandle {
#if EC_HAS_LEGACY_DDC
    IOI2CConnectRef connection;
#else
    void *unused;
#endif
};

#if EC_HAS_LEGACY_DDC
typedef io_service_t (*ECCGDisplayIOServicePortFn)(CGDirectDisplayID display_id);

static uint8_t ec_ddc_checksum(uint8_t seed, const uint8_t *bytes, size_t count) {
    uint8_t checksum = seed;
    for (size_t index = 0; index < count; index += 1) {
        checksum ^= bytes[index];
    }
    return checksum;
}

static bool ec_ddc_send(
    ECDDCHandle *handle,
    const uint8_t *send_buffer,
    uint32_t send_count,
    uint8_t *reply_buffer,
    uint32_t reply_count
) {
    if (handle == NULL || handle->connection == 0 || send_buffer == NULL) {
        return false;
    }

    IOI2CRequest request;
    memset(&request, 0, sizeof(request));
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendAddress = 0x6E;
    request.sendBuffer = (vm_address_t)send_buffer;
    request.sendBytes = send_count;

    if (reply_buffer != NULL && reply_count > 0) {
        request.replyTransactionType = kIOI2CDDCciReplyTransactionType;
        request.replyAddress = 0x6F;
        request.replyBuffer = (vm_address_t)reply_buffer;
        request.replyBytes = reply_count;
        request.minReplyDelay = 40 * 1000 * 1000;
    } else {
        request.replyTransactionType = kIOI2CNoTransactionType;
    }

    IOReturn result = IOI2CSendRequest(handle->connection, 0, &request);
    return result == kIOReturnSuccess && request.result == kIOReturnSuccess;
}
#endif

ECDDCHandle *ec_ddc_open(uint32_t display_id) {
#if EC_HAS_LEGACY_DDC
    void *application_services = dlopen(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices",
        RTLD_LAZY | RTLD_LOCAL
    );
    if (application_services == NULL) {
        return NULL;
    }
    ECCGDisplayIOServicePortFn display_service =
        (ECCGDisplayIOServicePortFn)dlsym(application_services, "CGDisplayIOServicePort");
    if (display_service == NULL) {
        dlclose(application_services);
        return NULL;
    }

    io_service_t framebuffer = display_service(display_id);
    dlclose(application_services);
    if (framebuffer == MACH_PORT_NULL) {
        return NULL;
    }

    IOItemCount bus_count = 0;
    if (IOFBGetI2CInterfaceCount(framebuffer, &bus_count) != kIOReturnSuccess) {
        return NULL;
    }

    for (IOOptionBits bus = 0; bus < bus_count; bus += 1) {
        io_service_t interface = MACH_PORT_NULL;
        if (IOFBCopyI2CInterfaceForBus(framebuffer, bus, &interface) != kIOReturnSuccess) {
            continue;
        }
        IOI2CConnectRef connection = 0;
        IOReturn result = IOI2CInterfaceOpen(interface, 0, &connection);
        IOObjectRelease(interface);
        if (result == kIOReturnSuccess && connection != 0) {
            ECDDCHandle *handle = calloc(1, sizeof(ECDDCHandle));
            if (handle == NULL) {
                IOI2CInterfaceClose(connection, 0);
                return NULL;
            }
            handle->connection = connection;
            return handle;
        }
    }
#else
    (void)display_id;
#endif
    return NULL;
}

void ec_ddc_close(ECDDCHandle *handle) {
    if (handle == NULL) {
        return;
    }
#if EC_HAS_LEGACY_DDC
    if (handle->connection != 0) {
        IOI2CInterfaceClose(handle->connection, 0);
    }
#endif
    free(handle);
}

bool ec_ddc_get_vcp10(
    ECDDCHandle *handle,
    uint16_t *current_value,
    uint16_t *maximum_value
) {
#if EC_HAS_LEGACY_DDC
    if (current_value == NULL || maximum_value == NULL) {
        return false;
    }
    uint8_t request[5] = { 0x51, 0x82, 0x01, 0x10, 0x00 };
    request[4] = ec_ddc_checksum(0x6E, request, 4);
    uint8_t reply[16];
    memset(reply, 0, sizeof(reply));
    if (!ec_ddc_send(handle, request, sizeof(request), reply, sizeof(reply))) {
        return false;
    }

    return ec_ddc_parse_vcp10_reply(reply, sizeof(reply), current_value, maximum_value);
#else
    (void)handle;
    (void)current_value;
    (void)maximum_value;
#endif
    return false;
}

// Parses a DDC/CI Get VCP Feature reply for VCP 0x10 (brightness).
//
// Reply layout per VESA DDC/CI (relative to the 0x02 command byte):
//   [0] = 0x02    feature reply op code
//   [1] = result code   (0x00 = no error, 0x01 = unsupported op code)
//   [2] = VCP code      (0x10 for brightness)
//   [3] = type code
//   [4] = maximum value high byte (mh)
//   [5] = maximum value low byte  (ml)
//   [6] = current value high byte (sh)
//   [7] = current value low byte  (sl)
//   [8] = checksum
//
// A leading address/destination byte (0x6F) may precede the 0x02 byte on
// some I2C transports, so the reply is scanned for the command marker.
bool ec_ddc_parse_vcp10_reply(
    const uint8_t *reply,
    size_t reply_count,
    uint16_t *current_value,
    uint16_t *maximum_value
) {
    if (reply == NULL || current_value == NULL || maximum_value == NULL) {
        return false;
    }
    // Need 9 bytes after the command byte: result, VCP code, type, mh, ml, sh, sl, checksum.
    for (size_t index = 0; index + 9 <= reply_count; index += 1) {
        if (reply[index] != 0x02 || reply[index + 2] != 0x10) {
            continue;
        }
        if (reply[index + 1] != 0x00) {
            // Result code is not "no error": unsupported or rejected feature.
            continue;
        }

        uint16_t maximum = (uint16_t)((reply[index + 4] << 8) | reply[index + 5]);
        uint16_t current = (uint16_t)((reply[index + 6] << 8) | reply[index + 7]);

        // DDC/CI checksum: XOR of all message bytes (including the checksum
        // byte itself) equals zero. Accept both plain and address-prefixed
        // forms so a stray leading destination byte cannot invalidate a good reply.
        uint8_t plain_xor = 0;
        for (size_t offset = 0; offset < 9; offset += 1) {
            plain_xor ^= reply[index + offset];
        }
        bool checksum_ok = (plain_xor == 0);
        if (!checksum_ok && index > 0) {
            uint8_t prefixed_xor = 0x6F;
            for (size_t offset = 0; offset < 9; offset += 1) {
                prefixed_xor ^= reply[index + offset];
            }
            checksum_ok = (prefixed_xor == 0);
        }
        if (!checksum_ok) {
            continue;
        }

        *maximum_value = maximum;
        *current_value = current;
        return maximum > 0;
    }
    return false;
}

bool ec_ddc_set_vcp10(ECDDCHandle *handle, uint16_t value) {
#if EC_HAS_LEGACY_DDC
    uint8_t request[7] = {
        0x51,
        0x84,
        0x03,
        0x10,
        (uint8_t)(value >> 8),
        (uint8_t)(value & 0xFF),
        0x00
    };
    request[6] = ec_ddc_checksum(0x6E, request, 6);
    return ec_ddc_send(handle, request, sizeof(request), NULL, 0);
#else
    (void)handle;
    (void)value;
    return false;
#endif
}
