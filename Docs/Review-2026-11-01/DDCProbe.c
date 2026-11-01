#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "ECPrivateAPIBridge.h"
int main(void) {
    // Full DDC/CI VCP 0x10 reply: source, length, opcode, status, VCP,
    // type, max high/low, current high/low, checksum.
    uint8_t reply[11]={0x6e,0x88,0x02,0x00,0x10,0x00,0x00,0x64,0x00,0x32,0};
    uint8_t sum=0x50;
    for(int i=0;i<10;i++) sum ^= reply[i];
    reply[10]=sum;
    uint16_t current=0, maximum=0;
    int valid=ec_ddc_parse_vcp10_reply(reply,11,&current,&maximum);
    printf("DDC_STANDARD: checksum=0x%02x accepted=%d (expected 1, brightness 50/100)\n",sum,valid);
    assert(!valid);
    // Corrupt only the checksum to match the current parser's reduced slice.
    sum=0;
    for(int i=2;i<10;i++) sum ^= reply[i];
    reply[10]=sum;
    int corrupt=ec_ddc_parse_vcp10_reply(reply,11,&current,&maximum);
    printf("DDC_BAD_CHECKSUM: checksum=0x%02x accepted=%d value=%u/%u (expected rejection)\n",sum,corrupt,current,maximum);
    assert(corrupt);
    return 0;
}
