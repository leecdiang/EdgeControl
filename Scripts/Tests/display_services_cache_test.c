// Compile the production bridge against a fake loader. No hardware is accessed.
#include <assert.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static void *fake_dlopen(const char *, int);
static void *fake_dlsym(void *, const char *);
static int fake_dlclose(void *);
#define dlopen fake_dlopen
#define dlsym fake_dlsym
#define dlclose fake_dlclose
#include "../../EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c"
#undef dlopen
#undef dlsym
#undef dlclose

static int loader_mode, opens, symbols, closes;
static int token;
static int32_t fake_get(uint32_t display, float *value) {
    *value = 0.5f;
    return display == 42 ? 0 : -1;
}
static int32_t fake_set(uint32_t display, float value) {
    return display == 42 && value == 0.75f ? 0 : -1;
}
static void *fake_dlopen(const char *path, int flags) {
    (void)flags;
    assert(strcmp(path, kECDisplayServicesPath) == 0);
    opens++;
    return loader_mode == 0 ? NULL : &token;
}
static void *fake_dlsym(void *handle, const char *name) {
    assert(handle == &token);
    symbols++;
    if (strcmp(name, "DisplayServicesGetBrightness") == 0) return (void *)fake_get;
    assert(strcmp(name, "DisplayServicesSetBrightness") == 0);
    return loader_mode == 1 ? NULL : (void *)fake_set;
}
static int fake_dlclose(void *handle) {
    assert(handle == &token);
    closes++;
    return 0;
}
static void *exercise(void *context) {
    (void)context;
    for (int i = 0; i < 100; i++) {
        float value = 0;
        assert(ec_display_services_is_available());
        assert(ec_display_services_get_brightness(42, &value) && value == 0.5f);
        assert(ec_display_services_set_brightness(42, 0.75f));
        // Lost/replaced displays must fail; caching symbols must not cache I/O.
        assert(!ec_display_services_get_brightness(43, &value));
        assert(!ec_display_services_set_brightness(43, 0.75f));
    }
    return NULL;
}
int main(void) {
    assert(!ec_display_services_get_brightness(42, NULL));
    assert(opens == 0);
    assert(!ec_display_services_is_available());
    assert(opens == 1 && closes == 0);
    loader_mode = 1;
    assert(!ec_display_services_is_available());
    assert(opens == 2 && symbols == 2 && closes == 1);
    loader_mode = 2;
    pthread_t threads[16];
    for (int i = 0; i < 16; i++) assert(pthread_create(&threads[i], NULL, exercise, NULL) == 0);
    for (int i = 0; i < 16; i++) assert(pthread_join(threads[i], NULL) == 0);
    assert(opens == 3 && symbols == 4 && closes == 1);
    puts("DisplayServices cache: failed loads retry, successful load is shared, I/O errors propagate (16 threads x 100 iterations).");
    return 0;
}
