const std = @import("std");
const Feature = std.Target.x86.Feature;
const join = std.fs.path.join;

pub fn build(b: *std.Build) !void {
    const add = std.Target.x86.featureSet(&.{.soft_float});
    const sub = std.Target.x86.featureSet(&.{ .mmx, .sse, .sse2, .avx, .avx2 });
    const target16 = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .code16,
        .cpu_features_add = add,
        .cpu_features_sub = sub,
    });
    const target32 = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_add = add,
        .cpu_features_sub = sub,
    });
    _ = target32;

    const boot_stage0 = b.addExecutable(.{
        .name = "boot_stage0",
        .root_source_file = b.path("boot/stage0/main.zig"),
        .target = target16,
        .optimize = .ReleaseSmall,
        .strip = true,
    });

    boot_stage0.setLinkerScript(b.path("boot/stage0/linker.ld"));
    boot_stage0.addAssemblyFile(b.path("boot/stage0/entry.S"));
    b.getInstallStep().dependOn(&b.addInstallArtifact(boot_stage0, .{}).step);
    const boot_stage0_bin = b.addObjCopy(boot_stage0.getEmittedBin(), .{ .format = .bin });

    const boot_stage1 = b.addExecutable(.{
        .name = "boot_stage1",
        .root_source_file = b.path("boot/stage1/main.zig"),
        .target = target16,
        .optimize = .ReleaseSmall,
        .strip = true,
    });

    boot_stage1.setLinkerScript(b.path("boot/stage1/linker.ld"));
    // boot_stage1.addAssemblyFile(b.path("boot/stage1/entry.S"));
    b.getInstallStep().dependOn(&b.addInstallArtifact(boot_stage1, .{}).step);
    const boot_stage1_bin = b.addObjCopy(boot_stage1.getEmittedBin(), .{ .format = .bin });

    const create_disk = b.addSystemCommand(&.{ "dd", "if=/dev/zero", "of=disk.img", "bs=1M", "count=128" });
    const create_partition_table = b.addSystemCommand(&.{ "mpartition", "-I", "-B" });
    create_partition_table.addFileArg(boot_stage0_bin.getOutput());
    create_partition_table.addArg("C:");
    create_partition_table.step.dependOn(&boot_stage0_bin.step);
    create_partition_table.step.dependOn(&create_disk.step);

    const create_partition = b.addSystemCommand(&.{ "mpartition", "-c", "-a", "C:" });
    create_partition.step.dependOn(&create_partition_table.step);

    const format_partition = b.addSystemCommand(&.{ "mformat", "-F", "-R", "64", "C:" });
    format_partition.step.dependOn(&boot_stage1_bin.step);
    format_partition.step.dependOn(&create_partition.step);

    // inject stage1 into disk.img
    const inject_stage1 = InjectStage1.init(
        b,
        b.path("disk.img"),
        boot_stage1_bin.getOutput(),
    );
    inject_stage1.step.dependOn(&format_partition.step);
    // inject_stage1.step.dependOn(b.getInstallStep());

    const make = b.step("make", "build bootloader and kernel");
    make.dependOn(&inject_stage1.step);
    // make.dependOn(&installAt(b, extended, "boot/extended.bin").step);
    make.dependOn(b.getInstallStep());
}

const InjectStage1 = struct {
    const Step = std.Build.Step;

    step: Step,
    disk_image: std.Build.LazyPath,
    stage1_bin: std.Build.LazyPath,

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

    const Self = @This();

    pub fn init(owner: *std.Build, disk_image: std.Build.LazyPath, stage1_bin: std.Build.LazyPath) *Self {
        const self = owner.allocator.create(Self) catch @panic("oom");
        const step = Step.init(.{
            .id = .custom,
            .name = "inject-stage1",
            .owner = owner,
            .makeFn = make,
        });

        self.* = Self{
            .step = step,
            .disk_image = disk_image,
            .stage1_bin = stage1_bin,
        };
        return self;
    }

    pub fn make(step: *Step, options: std.Build.Step.MakeOptions) !void {
        _ = options;

        const builder = step.owner;
        const self: *Self = @fieldParentPtr("step", step);

        const disk = try std.fs.openFileAbsolute(
            self.disk_image.getPath(builder),
            .{ .mode = .read_write },
        );

        const stage1_bin = try std.fs.openFileAbsolute(
            self.stage1_bin.getPath(builder),
            .{ .mode = .read_only },
        );
        const length = try stage1_bin.getEndPos();

        if (length > 64 * 512) {
            return step.fail("step1 bootloader too large", .{});
        }

        try disk.seekableStream().seekTo(446);
        const partition = try disk.reader().readStruct(Partition);
        std.debug.print("{any}", .{partition});
        if (partition.is_bootable()) {
            const offset = (partition.start_lba + 2) * 512;
            _ = try stage1_bin.copyRange(0, disk, offset, length);
            return;
        }

        return step.fail("partition 0 is not bootable", .{});
    }
};
