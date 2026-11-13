#ifndef MINAGER_RANDOMX_BRIDGE_H
#define MINAGER_RANDOMX_BRIDGE_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct minager_randomx minager_randomx;
minager_randomx *minager_rx_create(const uint8_t *key, size_t size, int useV2);
void minager_rx_hash(minager_randomx *ctx, const void *data, size_t length, void *output);
void minager_rx_destroy(minager_randomx *ctx);
#ifdef __cplusplus
}
#endif
#endif
