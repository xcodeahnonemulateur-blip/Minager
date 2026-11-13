#include "RandomXBridge.h"
#include "randomx.h"
#include <stdlib.h>
#include <stdint.h>
#include <libkern/OSCacheControl.h>

// The upstream ARM64 RandomX static archive references GCC's __clear_cache.
// iOS exports sys_icache_invalidate instead. Provide the tiny ABI shim so the
// unused JIT object can link; our miner explicitly runs the interpreter only.
void __clear_cache(void *begin, void *end) {
    uintptr_t first = (uintptr_t)begin;
    uintptr_t last = (uintptr_t)end;
    if (first != 0 && last > first) {
        sys_icache_invalidate(begin, (size_t)(last - first));
    }
}


struct minager_randomx {
    randomx_cache *cache;
    randomx_vm *vm;
};

minager_randomx *minager_rx_create(const uint8_t *key, size_t size, int useV2) {
    if (!key || !size) return NULL;
    minager_randomx *ctx = calloc(1, sizeof(minager_randomx));
    if (!ctx) return NULL;
    // Portable interpreter, no iOS JIT, no 2-GiB dataset.
    ctx->cache = randomx_alloc_cache(RANDOMX_FLAG_DEFAULT);
    if (!ctx->cache) { free(ctx); return NULL; }
    randomx_init_cache(ctx->cache, key, size);
    ctx->vm = randomx_create_vm(useV2 ? RANDOMX_FLAG_V2 : RANDOMX_FLAG_DEFAULT, ctx->cache, NULL);
    if (!ctx->vm) { randomx_release_cache(ctx->cache); free(ctx); return NULL; }
    return ctx;
}

void minager_rx_hash(minager_randomx *ctx, const void *data, size_t length, void *output) {
    if (!ctx || !ctx->vm || !data || !output) return;
    randomx_calculate_hash(ctx->vm, data, length, output);
}

void minager_rx_destroy(minager_randomx *ctx) {
    if (!ctx) return;
    if (ctx->vm) randomx_destroy_vm(ctx->vm);
    if (ctx->cache) randomx_release_cache(ctx->cache);
    free(ctx);
}
