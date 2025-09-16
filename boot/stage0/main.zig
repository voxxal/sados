const std = @import("std");

pub const Partition = packed struct {
    attributes: u8,
    start_chs: u24,
    type: u8,
    end_chs: u24,
    start_lba: u32,
    sectors: u32,

    pub fn is_bootable(self: *const @This()) bool {
        return self.attributes & (1 << 7) != 0;
    }
};

pub const Int13hPacket = packed struct {
    size: u8 = 0x10,
    _zero: u8 = 0,
    sectors: u16,
    offset: u16,
    segment: u16 = 0,
    lba: u64,
    fn verifiedEnabled() bool {
        return asm volatile (
            \\movb $0x41, %ah
            \\movw $0x55aa, %bx
            \\mov  $0x80, %dl
            \\int  $0x13
            \\setnc %al
            : [ret] "={al}" (-> bool),
            :
            : "ah", "bx", "dl"
        );
    }
    //returns error code
    fn execute(self: *const @This(), drive: u8) u8 {
        return asm volatile (
            \\movb $0x42, %ah
            \\int  $0x13
            : [ret] "={ah}" (-> u8),
            : [packet] "{si}" (@intFromPtr(self)),
              [drive] "{dl}" (drive),
            : "ah"
        );
    }
};

extern const __partition_table: usize;

export fn _zig_start(drive: u8) callconv(.C) noreturn {
    const partition_table_addr: u16 = @truncate(@intFromPtr(&__partition_table));
    const partition_table = @as([*]Partition, @ptrFromInt(partition_table_addr))[0..4];
    const partition = partition_table[0];
    if (!partition.is_bootable()) die("part. 0 is not bootable");
    if (!Int13hPacket.verifiedEnabled()) die("int13 extensions not enabled");
    // read bpb
    const bpb_addr = 0x8000;
    var packet: Int13hPacket align(16) = Int13hPacket{
        .sectors = 1,
        .offset = bpb_addr,
        .lba = partition.start_lba,
    };

    if (packet.execute(drive) != 0) die("bpb fail");
    const reserved_sectors: *u16 = @ptrFromInt(bpb_addr + 0x0E);
    packet.sectors = reserved_sectors.*;
    packet.lba += 2;
    if (packet.execute(drive) != 0) die("stage1 fail");
    print("jumping to stage1\r\n");
    const stage1 = @as(*const fn () noreturn, @ptrFromInt(0x8000));

    stage1();
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
