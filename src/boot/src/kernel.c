#include <stdint.h>

void kmain(void) {
    volatile uint16_t *d = (volatile uint16_t *)0xB8000;
    d[0] = 0x0F4B;
    d[2] = 0x0F4C;
    d[4] = 0x0F4D;
    while (1);
}
