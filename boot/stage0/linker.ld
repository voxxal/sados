ENTRY(_start)

SECTIONS {
    . = 0x7c00;

    .entry  : { KEEP(*(.entry)) }
    .text   : { KEEP(*(.text.*)) }
    .rodata : { KEEP(*(.rodata.*)) }
    .data   : { KEEP(*(.data.*)) }
    .bss    : { KEEP(*(.bss.*)) }

    . = 0x7c00 + 446;
    __partition_table = .;

    . = 0x7c00 + 510;
    .magic : { SHORT(0xaa55) }
}