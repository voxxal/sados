ENTRY(_start)

SECTIONS {
    . = 0x8000;

    .entry  : { KEEP(*(.entry)) }
    .text   : { KEEP(*(.text.*)) }
    .rodata : { KEEP(*(.rodata.*)) }
    .data   : { KEEP(*(.data.*)) }
    .bss    : { KEEP(*(.bss.*)) }
}