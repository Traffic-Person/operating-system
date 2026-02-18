#include <stdint.h>

#define PIC1_CMD      0x20
#define PIC1_DATA     0x21
#define PIC2_CMD      0xA0
#define PIC2_DATA     0xA1
#define KEYBOARD_PORT 0x60
#define VGA_COLS      80
#define VGA_ROWS      25

struct idt_entry {
    uint16_t base_low;
    uint16_t sel;
    uint8_t  always0;
    uint8_t  flags;
    uint16_t base_high;
} __attribute__((packed));

struct idt_ptr {
    uint16_t limit;
    uint32_t base;
} __attribute__((packed));

struct idt_entry idt[256];

static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0,%1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile("inb %1,%0" : "=a"(ret) : "Nd"(port));
    return ret;
}

static void pic_remap(void) {
    outb(PIC1_CMD,  0x11);
    outb(PIC2_CMD,  0x11);
    outb(PIC1_DATA, 0x20);
    outb(PIC2_DATA, 0x28);
    outb(PIC1_DATA, 0x04);
    outb(PIC2_DATA, 0x02);
    outb(PIC1_DATA, 0x01);
    outb(PIC2_DATA, 0x01);
    outb(PIC1_DATA, 0xFD);
    outb(PIC2_DATA, 0xFF);
}

static void set_idt_entry(int n, void (*handler)(void)) {
    uint32_t h = (uint32_t)handler;
    idt[n].base_low  = h & 0xFFFF;
    idt[n].sel       = 0x08;
    idt[n].always0   = 0;
    idt[n].flags     = 0x8E;
    idt[n].base_high = (h >> 16) & 0xFFFF;
}

static void idt_load(struct idt_ptr *idtp) {
    asm volatile("lidtl (%0)" : : "r"(idtp));
}

volatile uint16_t *vga = (volatile uint16_t *)0xB8000;
static uint16_t cursor = 0;

static void vga_clear(void) {
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++)
        vga[i] = (uint16_t)((0x0E << 8) | ' ');
}

static void vga_scroll(void) {
    for (int i = VGA_COLS; i < VGA_COLS * VGA_ROWS; i++)
        vga[i - VGA_COLS] = vga[i];
    for (int i = VGA_COLS * (VGA_ROWS - 1); i < VGA_COLS * VGA_ROWS; i++)
        vga[i] = (uint16_t)((0x0E << 8) | ' ');
    cursor = VGA_COLS * (VGA_ROWS - 1);
}

static void print_char(char c) {
    if (c == '\b') {
        if (cursor > VGA_COLS) {
            cursor--;
            vga[cursor] = (uint16_t)((0x0E << 8) | ' ');
        }
        return;
    }
    if (c == '\n') {
        cursor = (uint16_t)((cursor / VGA_COLS + 1) * VGA_COLS);
        if (cursor >= VGA_COLS * VGA_ROWS)
            vga_scroll();
        return;
    }
    if (c == '\t') {
        int spaces = 4 - ((cursor % VGA_COLS) % 4);
        for (int i = 0; i < spaces; i++)
            print_char(' ');
        return;
    }
    vga[cursor++] = (uint16_t)((0x0E << 8) | (uint8_t)c);
    if (cursor >= VGA_COLS * VGA_ROWS)
        vga_scroll();
}

static void print_str(const char *s) {
    while (*s) print_char(*s++);
}

void irq1_handler_c(void);
void irq1_handler_stub(void);

void irq1_handler_c(void) {
    static const char normal[128] = {
        0,   0,   '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
        '\t','q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
        0,   'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'','`',
        0,   '\\','z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0,
        '*', 0,   ' '
    };
    static const char shifted[128] = {
        0,   0,   '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', '\b',
        '\t','Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', '\n',
        0,   'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~',
        0,   '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0,
        '*', 0,   ' '
    };
    static int shift = 0;

    uint8_t sc = inb(KEYBOARD_PORT);

    if (sc == 0x2A || sc == 0x36) { shift = 1; goto eoi; }
    if (sc == 0xAA || sc == 0xB6) { shift = 0; goto eoi; }
    if (sc & 0x80) goto eoi;
    if (sc < 128) {
        char c = shift ? shifted[sc] : normal[sc];
        if (c) print_char(c);
    }
eoi:
    outb(PIC1_CMD, 0x20);
}

asm(
    ".global irq1_handler_stub\n"
    "irq1_handler_stub:\n"
    "    pusha\n"
    "    call irq1_handler_c\n"
    "    popa\n"
    "    iret\n"
);

void fault_handler(void);
asm(
    ".global fault_handler\n"
    "fault_handler:\n"
    "    cli\n"
    "    hlt\n"
);

static void install_default_handlers(void) {
    for (int i = 0; i < 256; i++)
        set_idt_entry(i, fault_handler);
}

void kmain(void) {
    vga_clear();
    vga[0] = (uint16_t)((0x0F << 8) | 'F');
    vga[1] = (uint16_t)((0x0F << 8) | 'T');
    cursor = VGA_COLS;
    print_str("Kernel loaded. Type below:\n");

    pic_remap();
    install_default_handlers();
    set_idt_entry(33, irq1_handler_stub);

    struct idt_ptr idtp;
    idtp.limit = sizeof(idt) - 1;
    idtp.base  = (uint32_t)&idt;
    idt_load(&idtp);

    asm volatile("sti");
    while (1) asm volatile("hlt");
}
