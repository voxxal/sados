    .intel_syntax noprefix
    .section .entry, "awx"
    .code16

    .extern _zig_start

    .global _start

_start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov sp, 0x7c00

    push edx

    call _zig_start