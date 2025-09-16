export fn _start() linksection(".entry") callconv(.C) noreturn {
    enableA20();
    print("Hello World!\r\n");
    print("I'm from stage 1!\r\n");
    print("We made it!\r\n");
    die("okay im going to hang now\r\n");
}

fn die(str: []const u8) noreturn {
    print(str);
    while (true) {}
}

fn print(str: []const u8) void {
    for (str) |c| {
        print_char(c);
    }
}

fn print_char(char: u8) void {
    asm volatile (
        \\xor %bh, %bh
        \\mov $0x07, %bl
        \\int $0x10
        :
        : [c] "{ax}" (0x0E00 | @as(u16, char)),
        : "bx"
    );
}

fn enableA20() void {
    asm volatile (
        \\in al, 0x92
        \\test al, 2
        \\jnz after
        \\or al, 2
        \\and al, 0xFE
        \\out 0x92, al
        ::: "al");
}

fn enableUnreal() void {
    asm volatile (
        \\
    );
}
const GDTDescriptor = packed struct {
    base: u32 = 0,
    limit: u20 = 0xFFFFF,
    access: u8,
    flags: u4 = 0xC,

    fn toFormat(self: @This()) u64 {
        var result: u64 = 0;
    }
};

const GDT = struct {
    null: u64,
    k_code: u64,
    k_data: u64,
    u_code: u64,
    u_data: u64,
};

const gdt: GDT = .{
    .null = @intFromPtr(&gdt),
    .k_code = (GDTDescriptor{ .access = 0x9A }).toFormat(),
    .k_data = (GDTDescriptor{ .access = 0x92 }).toFormat(),
    .u_code = (GDTDescriptor{ .access = 0xFA }).toFormat(),
    .u_data = (GDTDescriptor{ .access = 0xF2 }).toFormat(),
};

fn loadGDT() void {}
