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

    // Temporary ABI probe: dump raw bytes of the callback buffer.
    // Gated by EDGE_RAW_DUMP=1; removed once the ABI is confirmed.
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

ECMultitouchHandle *ec_mt_open(ECTouchFrameCallback callback, void *context) {
    if (callback == NULL) {
        return NULL;
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

    void *device = create_device();
    if (device == NULL) {
        dlclose(framework);
        return NULL;
    }

    ECMultitouchHandle *handle = calloc(1, sizeof(ECMultitouchHandle));
    if (handle == NULL) {
        if (release != NULL) {
            release(device);
        }
        dlclose(framework);
        return NULL;
    }

    handle->framework = framework;
    handle->device = device;
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

    if (handle->release != NULL) {
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

    // Accept the usual DDC/CI reply with optional leading destination byte.
    for (size_t index = 0; index + 8 < sizeof(reply); index += 1) {
        if (reply[index] == 0x02 && reply[index + 2] == 0x10) {
            *maximum_value = (uint16_t)((reply[index + 5] << 8) | reply[index + 6]);
            *current_value = (uint16_t)((reply[index + 7] << 8) | reply[index + 8]);
            return *maximum_value > 0;
        }
    }
#else
    (void)handle;
    (void)current_value;
    (void)maximum_value;
#endif
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
