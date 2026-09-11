// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// integration_test.zig -- Integration tests for the IDApTIK UMS Zig FFI.
// Author: Jonathan D.A. Jewell
//
// Tests the full create -> populate -> validate -> serialise lifecycle
// exercising every exported FFI function.

const std = @import("std");
const c = @cImport({
    @cInclude("idaptik_ums.h");
});

fn expectSameLayout(comptime ZigType: type, comptime CType: type) !void {
    try std.testing.expectEqual(@sizeOf(ZigType), @sizeOf(CType));
    try std.testing.expectEqual(@alignOf(ZigType), @alignOf(CType));
    inline for (std.meta.fields(ZigType)) |zig_field| {
        try std.testing.expectEqual(
            @offsetOf(ZigType, zig_field.name),
            @offsetOf(CType, zig_field.name),
        );
    }
}

fn expectEnumValues(comptime ZigType: type, comptime c_values: anytype) !void {
    const zig_fields = std.meta.fields(ZigType);
    try std.testing.expectEqual(zig_fields.len, c_values.len);
    inline for (zig_fields, 0..) |zig_field, index| {
        try std.testing.expectEqual(zig_field.value, c_values[index]);
    }
}

fn expectFunctionAbi(comptime zig_function: anytype, comptime c_function: anytype) !void {
    const zig_info = @typeInfo(@TypeOf(zig_function)).@"fn";
    const c_info = @typeInfo(@TypeOf(c_function)).@"fn";
    try std.testing.expectEqual(zig_info.calling_convention, c_info.calling_convention);
    try std.testing.expectEqual(zig_info.params.len, c_info.params.len);
    inline for (zig_info.params, c_info.params) |zig_param, c_param| {
        try std.testing.expectEqual(@sizeOf(zig_param.type.?), @sizeOf(c_param.type.?));
        try std.testing.expectEqual(@alignOf(zig_param.type.?), @alignOf(c_param.type.?));
    }
    if (zig_info.return_type) |zig_return| {
        const c_return = c_info.return_type.?;
        try std.testing.expectEqual(@sizeOf(zig_return), @sizeOf(c_return));
        try std.testing.expectEqual(@alignOf(zig_return), @alignOf(c_return));
    } else {
        try std.testing.expect(c_info.return_type == null);
    }
}
const types = @import("types");
const validate = @import("validate");
const main = @import("main");
const json_codec = @import("json_codec");
const inventory = @import("inventory");
const enemies = @import("enemies");
const mission_ffi = @import("mission");
const wiring = @import("wiring");
const proven_bridge = @import("proven_bridge");
const multiplayer = @import("multiplayer");
const game_systems = @import("game_systems");
const ipc_handlers = @import("ipc_handlers");

// =========================================================================
// Helpers
// =========================================================================

/// Create a level via the FFI, returning a non-null pointer or failing the test.
fn createTestLevel() *types.LevelData {
    return main.idaptik_ums_create_level() orelse {
        @panic("idaptik_ums_create_level returned null");
    };
}

fn expectCStrEqual(expected: []const u8, actual: ?[*:0]const u8) !void {
    try std.testing.expect(actual != null);
    try std.testing.expectEqualStrings(expected, std.mem.span(actual.?));
}

// =========================================================================
// Test: create and destroy lifecycle
// =========================================================================

test "create_level returns non-null and destroy is safe" {
    const level = createTestLevel();
    // A freshly created level should have all counts at zero.
    try std.testing.expectEqual(@as(u32, 0), level.devices_len);
    try std.testing.expectEqual(@as(u32, 0), level.zones_len);
    try std.testing.expectEqual(@as(u32, 0), level.guards_len);
    try std.testing.expectEqual(@as(u32, 0), level.dogs_len);
    try std.testing.expectEqual(@as(u32, 0), level.drones_len);
    try std.testing.expectEqual(@as(u32, 0), level.assassins_len);
    try std.testing.expectEqual(@as(u32, 0), level.items_len);
    try std.testing.expectEqual(@as(u32, 0), level.wiring_len);
    try std.testing.expectEqual(false, level.has_pbx);
    main.idaptik_ums_destroy_level(level);
}

test "destroy_level with null is a no-op" {
    main.idaptik_ums_destroy_level(null);
}

// =========================================================================
// Test: add_device
// =========================================================================

test "add_device populates the device array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const spec = types.DeviceSpec{
        .kind = .server,
        .ip = types.IpAddress.init(10, 0, 0, 1),
        .name = "core-server",
        .security = .strong,
    };

    const ok = main.idaptik_ums_add_device(level, &spec);
    try std.testing.expect(ok);
    try std.testing.expectEqual(@as(u32, 1), level.devices_len);
    try std.testing.expect(level.devices[0].ip.eql(types.IpAddress.init(10, 0, 0, 1)));
    try std.testing.expectEqual(types.DeviceKind.server, level.devices[0].kind);
}

test "add_device with null level returns false" {
    const spec = types.DeviceSpec{
        .kind = .laptop,
        .ip = types.IpAddress.init(10, 0, 0, 2),
        .name = "test",
        .security = .open,
    };
    try std.testing.expect(!main.idaptik_ums_add_device(null, &spec));
}

// =========================================================================
// Test: add_zone
// =========================================================================

test "add_zone populates the zone array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const zone = types.Zone{
        .name = "lobby",
        .security_tier = 1,
    };
    try std.testing.expect(main.idaptik_ums_add_zone(level, &zone));
    try std.testing.expectEqual(@as(u32, 1), level.zones_len);
}

// =========================================================================
// Test: add_guard
// =========================================================================

test "add_guard populates the guard array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const guard = types.GuardPlacement{
        .world_x = .{ .position = 100.0 },
        .zone = "lobby",
        .rank = .enforcer,
        .patrol_radius = 25.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &guard));
    try std.testing.expectEqual(@as(u32, 1), level.guards_len);
    try std.testing.expectEqual(types.GuardRank.enforcer, level.guards[0].rank);
}

// =========================================================================
// Test: add_dog
// =========================================================================

test "add_dog populates the dog array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const dog = types.DogPlacement{
        .world_x = .{ .position = 200.0 },
        .breed = .bloodhound,
        .patrol_radius = 50.0,
    };
    try std.testing.expect(main.idaptik_ums_add_dog(level, &dog));
    try std.testing.expectEqual(@as(u32, 1), level.dogs_len);
}

// =========================================================================
// Test: add_drone
// =========================================================================

test "add_drone populates the drone array" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const drone = types.DronePlacement{
        .world_x = .{ .position = 300.0 },
        .archetype = .hunter,
        .altitude = 15.0,
    };
    try std.testing.expect(main.idaptik_ums_add_drone(level, &drone));
    try std.testing.expectEqual(@as(u32, 1), level.drones_len);
}

// =========================================================================
// Test: set_mission
// =========================================================================

test "set_mission configures the mission" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const mission = types.MissionConfig{
        .mission_id = "m-001",
        .location_id = "data-centre-alpha",
        .objectives = null,
        .objectives_len = 0,
        .has_time_limit = true,
        .time_limit = 600,
    };
    try std.testing.expect(main.idaptik_ums_set_mission(level, &mission));
    try std.testing.expect(level.mission.has_time_limit);
    try std.testing.expectEqual(@as(u32, 600), level.mission.time_limit);
}

// =========================================================================
// Test: set_physical
// =========================================================================

test "set_physical configures physical world" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const physical = types.PhysicalConfig{
        .ground_y = 0.0,
        .world_width = 5000.0,
        .interaction_distance = 2.5,
        .has_power_system = true,
        .has_security_cameras = true,
        .number_of_covert_links = 3,
    };
    try std.testing.expect(main.idaptik_ums_set_physical(level, &physical));
    try std.testing.expectEqual(@as(f64, 5000.0), level.physical.world_width);
    try std.testing.expect(level.physical.has_power_system);
}

// =========================================================================
// Test: validation — empty level passes
// =========================================================================

test "empty level passes validation" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.valid);
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.guards_in_zones);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — guard in non-existent zone fails
// =========================================================================

test "guard referencing non-existent zone fails guards_in_zones" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Add a guard referencing "server-room" but no zones exist.
    const guard = types.GuardPlacement{
        .world_x = .{ .position = 50.0 },
        .zone = "server-room",
        .rank = .basic_guard,
        .patrol_radius = 10.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &guard));

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.valid);
    try std.testing.expect(!result.guards_in_zones);
    // Other checks should still pass.
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — guard in valid zone passes
// =========================================================================

test "guard referencing existing zone passes guards_in_zones" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const zone = types.Zone{ .name = "lobby", .security_tier = 1 };
    _ = main.idaptik_ums_add_zone(level, &zone);

    const guard = types.GuardPlacement{
        .world_x = .{ .position = 50.0 },
        .zone = "lobby",
        .rank = .sentinel,
        .patrol_radius = 15.0,
    };
    _ = main.idaptik_ums_add_guard(level, &guard);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.guards_in_zones);
}

// =========================================================================
// Test: validation — unordered zone transitions fail
// =========================================================================

test "unordered zone transitions fail zones_ordered" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Manually insert transitions out of order.
    level.zone_transitions[0] = .{
        .world_x = .{ .position = 500.0 },
        .from_zone = "a",
        .to_zone = "b",
    };
    level.zone_transitions[1] = .{
        .world_x = .{ .position = 100.0 },
        .from_zone = "b",
        .to_zone = "c",
    };
    level.zone_transitions_len = 2;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.zones_ordered);
}

// =========================================================================
// Test: validation — ordered zone transitions pass
// =========================================================================

test "ordered zone transitions pass zones_ordered" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.zone_transitions[0] = .{
        .world_x = .{ .position = 100.0 },
        .from_zone = "a",
        .to_zone = "b",
    };
    level.zone_transitions[1] = .{
        .world_x = .{ .position = 500.0 },
        .from_zone = "b",
        .to_zone = "c",
    };
    level.zone_transitions_len = 2;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.zones_ordered);
}

// =========================================================================
// Test: validation — PBX consistency
// =========================================================================

test "PBX enabled without matching device fails pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.pbx_consistent);
    try std.testing.expect(!result.valid);
}

test "PBX enabled with matching device passes pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const pbx_device = types.DeviceSpec{
        .kind = .phone_system,
        .ip = types.IpAddress.init(10, 0, 0, 99),
        .name = "pbx-main",
        .security = .medium,
    };
    _ = main.idaptik_ums_add_device(level, &pbx_device);
    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99);

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.pbx_consistent);
}

test "PBX disabled always passes pbx_consistent" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.has_pbx = false;
    level.pbx_ip = types.IpAddress.init(10, 0, 0, 99); // No device, but PBX off.

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.pbx_consistent);
}

// =========================================================================
// Test: validation — defence targets
// =========================================================================

test "defence config referencing non-existent device fails" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(!result.defence_targets_valid);
}

test "defence config referencing existing device passes" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    const dev = types.DeviceSpec{
        .kind = .firewall,
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .name = "fw-1",
        .security = .strong,
    };
    _ = main.idaptik_ums_add_device(level, &dev);
    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 0, 50),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.defence_targets_valid);
}

// =========================================================================
// Test: serialisation round-trip
// =========================================================================

test "serialize produces non-empty JSON" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // Add a device so there is something to serialise.
    const dev = types.DeviceSpec{
        .kind = .router,
        .ip = types.IpAddress.init(192, 168, 1, 1),
        .name = "gateway",
        .security = .medium,
    };
    _ = main.idaptik_ums_add_device(level, &dev);
    const mission = types.MissionConfig{
        .mission_id = "serialization-smoke",
        .location_id = "test-lab",
        .objectives = null,
        .objectives_len = 0,
        .has_time_limit = false,
        .time_limit = 0,
    };
    try std.testing.expect(main.idaptik_ums_set_mission(level, &mission));

    var buf: [8192]u8 = undefined;
    var diagnostic_stream = std.io.fixedBufferStream(&buf);
    try json_codec.serializeLevelJson(std.testing.allocator, level, diagnostic_stream.writer());
    const written = main.idaptik_ums_serialize_level(level, &buf, buf.len);
    try std.testing.expect(written > 0);

    // Check that it starts with '{' and ends with '}'.
    try std.testing.expectEqual(@as(u8, '{'), buf[0]);
    try std.testing.expectEqual(@as(u8, '}'), buf[written - 1]);
}

test "serialize with null level returns 0" {
    var buf: [64]u8 = undefined;
    const written = main.idaptik_ums_serialize_level(null, &buf, buf.len);
    try std.testing.expectEqual(@as(usize, 0), written);
}

test "shared Idris2-Zig JSON admission corpus has identical outcomes" {
    try std.testing.expect(!main.idaptik_ums_admit_level_json(null, 0));
    const one_byte = [_]u8{'{'};
    try std.testing.expect(!main.idaptik_ums_admit_level_json(&one_byte, 1024 * 1024 + 1));

    const allocator = std.testing.allocator;
    const accepted_paths = [_][]const u8{
        "tests/abi-parity/valid-full-level.json",
        "tests/abi-parity/accept-u32-max.json",
        "tests/abi-parity/accept-objective-capacity.json",
        "tests/abi-parity/accept-security-chief.json",
        "tests/abi-parity/accept-unknown-top-level-field.json",
    };
    for (accepted_paths) |path| {
        const fixture = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(fixture);
        try std.testing.expect(main.idaptik_ums_admit_level_json(fixture.ptr, fixture.len));
    }

    const rejected_paths = [_][]const u8{
        "tests/abi-parity/reject-defence-target.json",
        "tests/abi-parity/reject-guard-zone.json",
        "tests/abi-parity/reject-transition-order.json",
        "tests/abi-parity/reject-pbx.json",
        "tests/abi-parity/reject-malformed-ip.json",
        "tests/abi-parity/reject-u32-overflow.json",
        "tests/abi-parity/reject-objective-overflow.json",
        "tests/abi-parity/reject-embedded-nul.json",
        "tests/abi-parity/reject-chief-alias.json",
    };
    for (rejected_paths) |path| {
        const fixture = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(fixture);
        try std.testing.expect(!main.idaptik_ums_admit_level_json(fixture.ptr, fixture.len));
    }
}

test "complete C LevelData survives JSON round-trip without field loss" {
    const allocator = std.testing.allocator;
    const fixture = try std.fs.cwd().readFileAlloc(allocator, "tests/abi-roundtrip/full-c-layout.json", 1024 * 1024);
    defer allocator.free(fixture);

    // The testing allocator reports any arena or wrapper allocation that the
    // ownership-aware destroy path fails to release.
    const ownership_probe = try json_codec.deserializeLevelJson(allocator, fixture);
    json_codec.destroyOwned(allocator, ownership_probe);

    const first = main.idaptik_ums_deserialize_level(fixture.ptr, fixture.len) orelse return error.TestUnexpectedResult;
    defer main.idaptik_ums_destroy_level(first);
    try std.testing.expectEqual(@as(u32, 2), first.devices_len);
    try expectCStrEqual("pbx-core", first.devices[0].name);
    try std.testing.expectEqual(types.DeviceKind.phone_system, first.devices[0].kind);
    try std.testing.expectEqual(@as(u32, 2), first.zones_len);
    try expectCStrEqual("lobby", first.zones[0].name);
    try std.testing.expectEqual(@as(u32, 1), first.guards_len);
    try expectCStrEqual("lobby", first.guards[0].zone);
    try std.testing.expectEqual(types.GuardRank.security_chief, first.guards[0].rank);
    try std.testing.expectEqual(@as(u32, 1), first.dogs_len);
    try std.testing.expectEqual(@as(u32, 1), first.drones_len);
    try std.testing.expectEqual(@as(u32, 1), first.assassins_len);
    try std.testing.expectEqual(@as(u32, 8), first.items_len);
    try expectCStrEqual("cable", first.items[0].item.id);
    try std.testing.expectEqual(types.ItemKindTag.cable, first.items[0].item.kind.tag);
    try std.testing.expectEqual(types.ItemKindTag.adapter, first.items[1].item.kind.tag);
    try std.testing.expectEqual(types.ItemKindTag.tool, first.items[2].item.kind.tag);
    try std.testing.expectEqual(types.ItemKindTag.module_, first.items[3].item.kind.tag);
    try std.testing.expectEqual(types.ItemKindTag.storage, first.items[4].item.kind.tag);
    try std.testing.expectEqual(@as(u32, 4096), first.items[4].item.kind.capacity);
    try std.testing.expectEqual(types.ItemKindTag.consumable, first.items[5].item.kind.tag);
    try std.testing.expectEqual(types.ItemKindTag.keycard, first.items[6].item.kind.tag);
    try expectCStrEqual("vault", first.items[6].item.kind.zone_name);
    try std.testing.expectEqual(types.ItemKindTag.radio, first.items[7].item.kind.tag);
    try std.testing.expectEqual(@as(u32, 1), first.wiring_len);
    try expectCStrEqual("full-c-layout", first.mission.mission_id);
    try expectCStrEqual("exchange", first.mission.location_id);
    try std.testing.expectEqual(@as(u32, 2), first.mission.objectives_len);
    try expectCStrEqual("enter", first.mission.objectives.?[0].id);
    try std.testing.expect(first.mission.objectives.?[0].required);
    try std.testing.expect(first.mission.has_time_limit);
    try std.testing.expectEqual(@as(u32, 600), first.mission.time_limit);
    try std.testing.expectEqual(@as(u32, 5), first.physical.number_of_covert_links);
    try std.testing.expectEqual(@as(u32, 2), first.zone_transitions_len);
    try expectCStrEqual("vault", first.zone_transitions[1].to_zone);
    try std.testing.expectEqual(@as(u32, 1), first.device_defences_len);
    try std.testing.expect(first.device_defences[0].flags.tamper_proof);
    try std.testing.expect(first.device_defences[0].flags.decoy);
    try std.testing.expect(first.device_defences[0].flags.canary);
    try std.testing.expect(first.device_defences[0].flags.one_way_mirror);
    try std.testing.expect(first.device_defences[0].flags.kill_switch);
    try std.testing.expect(first.device_defences[0].flags.failover_target.has_value);
    try std.testing.expect(first.device_defences[0].flags.cascade_trap.has_value);
    try std.testing.expect(first.device_defences[0].flags.mirror_target.has_value);
    const whitelist = std.mem.span(first.device_defences[0].flags.instruction_whitelist.?);
    try std.testing.expectEqual(@as(usize, 2), whitelist.len);
    try expectCStrEqual("dial", whitelist[0]);
    try std.testing.expect(first.device_defences[0].flags.has_time_bomb);
    try std.testing.expect(first.device_defences[0].flags.has_undo_immunity);
    try std.testing.expect(first.has_pbx);
    try std.testing.expect(first.pbx_ip.eql(types.IpAddress.init(10, 8, 0, 1)));
    try std.testing.expectEqual(@as(f64, 33.5), first.pbx_world_x.position);

    var first_json: [65536]u8 = undefined;
    const first_len = main.idaptik_ums_serialize_level(first, &first_json, first_json.len);
    try std.testing.expect(first_len > 0);
    try std.testing.expect(main.idaptik_ums_admit_level_json(&first_json, first_len));

    const second = main.idaptik_ums_deserialize_level(&first_json, first_len) orelse return error.TestUnexpectedResult;
    defer main.idaptik_ums_destroy_level(second);
    var second_json: [65536]u8 = undefined;
    const second_len = main.idaptik_ums_serialize_level(second, &second_json, second_json.len);
    try std.testing.expectEqual(first_len, second_len);
    try std.testing.expectEqualSlices(u8, first_json[0..first_len], second_json[0..second_len]);
}

test "generated Idris2 C header matches every bounded LevelData Zig layout" {
    try expectSameLayout(types.IpAddress, c.ums_ip_address);
    try expectSameLayout(types.Percentage, c.ums_percentage);
    try expectSameLayout(types.WorldX, c.ums_world_x);
    try expectSameLayout(types.ItemKind, c.ums_item_kind);
    try expectSameLayout(types.DeviceSpec, c.ums_device_spec);
    try expectSameLayout(types.OptionalIpAddress, c.ums_optional_ip_address);
    try expectSameLayout(types.DefenceFlags, c.ums_defence_flags);
    try expectSameLayout(types.DeviceDefenceConfig, c.ums_device_defence_config);
    try expectSameLayout(types.Zone, c.ums_zone);
    try expectSameLayout(types.ZoneTransition, c.ums_zone_transition);
    try expectSameLayout(types.Item, c.ums_item);
    try expectSameLayout(types.WorldItem, c.ums_world_item);
    try expectSameLayout(types.GuardPlacement, c.ums_guard_placement);
    try expectSameLayout(types.DogPlacement, c.ums_dog_placement);
    try expectSameLayout(types.DronePlacement, c.ums_drone_placement);
    try expectSameLayout(types.AssassinConfig, c.ums_assassin_config);
    try expectSameLayout(types.MissionObjective, c.ums_mission_objective);
    try expectSameLayout(types.MissionConfig, c.ums_mission_config);
    try expectSameLayout(types.WiringChallenge, c.ums_wiring_challenge);
    try expectSameLayout(types.PhysicalConfig, c.ums_physical_config);
    try expectSameLayout(types.LevelData, c.ums_level_data);
    try expectSameLayout(types.ValidationResult, c.ums_validation_result);

    try std.testing.expectEqual(@sizeOf(types.SecurityLevel), @sizeOf(c.ums_security_level));
    try std.testing.expectEqual(@sizeOf(types.DeviceKind), @sizeOf(c.ums_device_kind));
    try std.testing.expectEqual(@sizeOf(types.GuardRank), @sizeOf(c.ums_guard_rank));
    try std.testing.expectEqual(@sizeOf(types.DogBreed), @sizeOf(c.ums_dog_breed));
    try std.testing.expectEqual(@sizeOf(types.DroneArchetype), @sizeOf(c.ums_drone_archetype));
    try std.testing.expectEqual(@sizeOf(types.AlertLevel), @sizeOf(c.ums_alert_level));
    try std.testing.expectEqual(@sizeOf(types.ItemCondition), @sizeOf(c.ums_item_condition));
    try std.testing.expectEqual(@sizeOf(types.CableType), @sizeOf(c.ums_cable_type));
    try std.testing.expectEqual(@sizeOf(types.AdapterType), @sizeOf(c.ums_adapter_type));
    try std.testing.expectEqual(@sizeOf(types.ToolType), @sizeOf(c.ums_tool_type));
    try std.testing.expectEqual(@sizeOf(types.ModuleType), @sizeOf(c.ums_module_type));
    try std.testing.expectEqual(@sizeOf(types.ConsumableType), @sizeOf(c.ums_consumable_type));
    try std.testing.expectEqual(@sizeOf(types.ItemKindTag), @sizeOf(c.ums_item_kind_tag));
    try std.testing.expectEqual(@sizeOf(types.WiringType), @sizeOf(c.ums_wiring_type));
    try std.testing.expectEqual(@sizeOf(types.ValidationCheck), @sizeOf(c.ums_validation_check));

    try expectEnumValues(types.SecurityLevel, .{ c.UMS_SECURITY_OPEN, c.UMS_SECURITY_WEAK, c.UMS_SECURITY_MEDIUM, c.UMS_SECURITY_STRONG });
    try expectEnumValues(types.DeviceKind, .{ c.UMS_DEVICE_LAPTOP, c.UMS_DEVICE_DESKTOP, c.UMS_DEVICE_SERVER, c.UMS_DEVICE_ROUTER, c.UMS_DEVICE_SWITCH, c.UMS_DEVICE_FIREWALL, c.UMS_DEVICE_CAMERA, c.UMS_DEVICE_ACCESS_POINT, c.UMS_DEVICE_PATCH_PANEL, c.UMS_DEVICE_POWER_SUPPLY, c.UMS_DEVICE_PHONE_SYSTEM, c.UMS_DEVICE_FIBRE_HUB });
    try expectEnumValues(types.GuardRank, .{ c.UMS_GUARD_BASIC, c.UMS_GUARD_ENFORCER, c.UMS_GUARD_ANTI_HACKER, c.UMS_GUARD_SENTINEL, c.UMS_GUARD_ASSASSIN, c.UMS_GUARD_ELITE, c.UMS_GUARD_SECURITY_CHIEF, c.UMS_GUARD_RIVAL_HACKER });
    try expectEnumValues(types.DogBreed, .{ c.UMS_DOG_PATROL, c.UMS_DOG_BLOODHOUND, c.UMS_DOG_ROBO });
    try expectEnumValues(types.DroneArchetype, .{ c.UMS_DRONE_HELPER, c.UMS_DRONE_HUNTER, c.UMS_DRONE_KILLER });
    try expectEnumValues(types.AlertLevel, .{ c.UMS_ALERT_GREEN, c.UMS_ALERT_YELLOW, c.UMS_ALERT_ORANGE, c.UMS_ALERT_RED });
    try expectEnumValues(types.ItemCondition, .{ c.UMS_CONDITION_PRISTINE, c.UMS_CONDITION_GOOD, c.UMS_CONDITION_WORN, c.UMS_CONDITION_DAMAGED, c.UMS_CONDITION_BROKEN });
    try expectEnumValues(types.CableType, .{ c.UMS_CABLE_ETHERNET, c.UMS_CABLE_FIBRE_LC, c.UMS_CABLE_FIBRE_SC, c.UMS_CABLE_SERIAL, c.UMS_CABLE_USB, c.UMS_CABLE_UNIVERSAL });
    try expectEnumValues(types.AdapterType, .{ c.UMS_ADAPTER_ETHERNET_TO_FIBRE, c.UMS_ADAPTER_USB_TO_SERIAL, c.UMS_ADAPTER_MEDIA_CONVERTER });
    try expectEnumValues(types.ToolType, .{ c.UMS_TOOL_CRIMPER, c.UMS_TOOL_SPLICER, c.UMS_TOOL_MULTIMETER, c.UMS_TOOL_WIRE_CUTTER, c.UMS_TOOL_DEBUGGER });
    try expectEnumValues(types.ModuleType, .{ c.UMS_MODULE_SFP, c.UMS_MODULE_GBIC, c.UMS_MODULE_QSFP, c.UMS_MODULE_TRANSCEIVER });
    try expectEnumValues(types.ConsumableType, .{ c.UMS_CONSUMABLE_BATTERY_PACK, c.UMS_CONSUMABLE_EMP, c.UMS_CONSUMABLE_SMOKE_GRENADE, c.UMS_CONSUMABLE_DECRYPTOR });
    try expectEnumValues(types.ItemKindTag, .{ c.UMS_ITEM_KIND_CABLE, c.UMS_ITEM_KIND_ADAPTER, c.UMS_ITEM_KIND_TOOL, c.UMS_ITEM_KIND_MODULE, c.UMS_ITEM_KIND_STORAGE, c.UMS_ITEM_KIND_CONSUMABLE, c.UMS_ITEM_KIND_KEYCARD, c.UMS_ITEM_KIND_RADIO });
    try expectEnumValues(types.WiringType, .{ c.UMS_WIRING_PATCH_PANEL, c.UMS_WIRING_SWITCH_BACKPLANE, c.UMS_WIRING_SERVER_RACK, c.UMS_WIRING_FIBRE_SPLICING, c.UMS_WIRING_PBX_COMMS });
    try expectEnumValues(types.ValidationCheck, .{ c.UMS_VALIDATION_DEFENCE_TARGETS, c.UMS_VALIDATION_GUARDS_IN_ZONES, c.UMS_VALIDATION_ZONES_ORDERED, c.UMS_VALIDATION_PBX_CONSISTENT });
}

test "generated Idris2 C header matches auxiliary Zig ABI layouts and discriminants" {
    try expectSameLayout(multiplayer.PlayerInfo, c.ums_player_info);
    try expectSameLayout(multiplayer.ChatMessage, c.ums_chat_message);
    try expectSameLayout(multiplayer.SessionState, c.ums_session_state);
    try expectSameLayout(game_systems.DetectionEvent, c.ums_detection_event);
    try expectSameLayout(game_systems.PlayerState, c.ums_player_state);

    try std.testing.expectEqual(@sizeOf(multiplayer.CoopRole), @sizeOf(c.ums_coop_role));
    try std.testing.expectEqual(@sizeOf(multiplayer.ConnectionState), @sizeOf(c.ums_connection_state));
    try std.testing.expectEqual(@sizeOf(multiplayer.SessionPhase), @sizeOf(c.ums_session_phase));
    try std.testing.expectEqual(@sizeOf(multiplayer.AlertLevel), @sizeOf(c.ums_multiplayer_alert));
    try std.testing.expectEqual(@sizeOf(multiplayer.SyncMessageKind), @sizeOf(c.ums_sync_message_kind));
    try std.testing.expectEqual(@sizeOf(game_systems.DamageType), @sizeOf(c.ums_damage_type));
    try std.testing.expectEqual(@sizeOf(game_systems.CriticalOutcome), @sizeOf(c.ums_critical_outcome));
    try std.testing.expectEqual(@sizeOf(game_systems.DetectionSource), @sizeOf(c.ums_detection_source));
    try std.testing.expectEqual(@sizeOf(game_systems.JessicaSubclass), @sizeOf(c.ums_jessica_subclass));
    try std.testing.expectEqual(@sizeOf(game_systems.QCertification), @sizeOf(c.ums_q_certification));
    try std.testing.expectEqual(@sizeOf(game_systems.LoadoutSlot), @sizeOf(c.ums_loadout_slot));
    try std.testing.expectEqual(@sizeOf(game_systems.Attribute), @sizeOf(c.ums_attribute));

    try expectEnumValues(multiplayer.CoopRole, .{ c.UMS_COOP_ROLE_JESSICA, c.UMS_COOP_ROLE_Q_HACKER, c.UMS_COOP_ROLE_OBSERVER });
    try expectEnumValues(multiplayer.ConnectionState, .{ c.UMS_CONNECTION_OFFLINE, c.UMS_CONNECTION_CONNECTING, c.UMS_CONNECTION_IN_LOBBY, c.UMS_CONNECTION_IN_SESSION });
    try expectEnumValues(multiplayer.SessionPhase, .{ c.UMS_SESSION_LOBBY, c.UMS_SESSION_COUNTDOWN, c.UMS_SESSION_LOADING, c.UMS_SESSION_PLAYING, c.UMS_SESSION_PAUSED, c.UMS_SESSION_COMPLETE });
    try expectEnumValues(multiplayer.AlertLevel, .{ c.UMS_MP_ALERT_GREEN, c.UMS_MP_ALERT_YELLOW, c.UMS_MP_ALERT_ORANGE, c.UMS_MP_ALERT_RED });
    try expectEnumValues(multiplayer.SyncMessageKind, .{ c.UMS_SYNC_POSITION, c.UMS_SYNC_VM_EXECUTE, c.UMS_SYNC_VM_UNDO, c.UMS_SYNC_VM_STATE, c.UMS_SYNC_BEBOP_DISCOVERED, c.UMS_SYNC_BEBOP_ACTIVATED, c.UMS_SYNC_BEBOP_COOP_REQ, c.UMS_SYNC_BEBOP_COOP_ACCEPT, c.UMS_SYNC_DEVICE_ACCESSED, c.UMS_SYNC_ALERT_CHANGED, c.UMS_SYNC_CHAT });
    try expectEnumValues(game_systems.DamageType, .{ c.UMS_DAMAGE_PHYSICAL, c.UMS_DAMAGE_ELECTRIC, c.UMS_DAMAGE_CYBER, c.UMS_DAMAGE_FALL });
    try expectEnumValues(game_systems.CriticalOutcome, .{ c.UMS_CRITICAL_FAILURE, c.UMS_CRITICAL_NORMAL, c.UMS_CRITICAL_SUCCESS, c.UMS_CRITICAL_PERFECT });
    try expectEnumValues(game_systems.DetectionSource, .{ c.UMS_DETECTION_CAMERA, c.UMS_DETECTION_GUARD, c.UMS_DETECTION_DOG, c.UMS_DETECTION_DRONE, c.UMS_DETECTION_ALARM, c.UMS_DETECTION_NOISE, c.UMS_DETECTION_CYBER_TRACE });
    try expectEnumValues(game_systems.JessicaSubclass, .{ c.UMS_SUBCLASS_ASSAULT, c.UMS_SUBCLASS_RECON, c.UMS_SUBCLASS_ENGINEER, c.UMS_SUBCLASS_SIGNALS, c.UMS_SUBCLASS_MEDIC, c.UMS_SUBCLASS_LOGISTICS });
    try expectEnumValues(game_systems.QCertification, .{ c.UMS_CERT_NETWORK_EXPLOIT, c.UMS_CERT_CRYPTO_ANALYSIS, c.UMS_CERT_SOCIAL_ENG, c.UMS_CERT_FORENSIC_ANALYSIS, c.UMS_CERT_MALWARE_DESIGN, c.UMS_CERT_COUNTER_INTEL });
    try expectEnumValues(game_systems.LoadoutSlot, .{ c.UMS_LOADOUT_WEAPON, c.UMS_LOADOUT_TOOL, c.UMS_LOADOUT_CONSUMABLE });
    try expectEnumValues(game_systems.Attribute, .{ c.UMS_ATTRIBUTE_STR, c.UMS_ATTRIBUTE_DEX, c.UMS_ATTRIBUTE_INT, c.UMS_ATTRIBUTE_CON, c.UMS_ATTRIBUTE_WIL, c.UMS_ATTRIBUTE_CHA });
}

test "generated Idris2 C header core and domain function signatures are ABI-compatible" {
    try expectFunctionAbi(main.idaptik_ums_create_level, c.idaptik_ums_create_level);
    try expectFunctionAbi(main.idaptik_ums_destroy_level, c.idaptik_ums_destroy_level);
    try expectFunctionAbi(main.idaptik_ums_add_device, c.idaptik_ums_add_device);
    try expectFunctionAbi(main.idaptik_ums_add_zone, c.idaptik_ums_add_zone);
    try expectFunctionAbi(main.idaptik_ums_add_guard, c.idaptik_ums_add_guard);
    try expectFunctionAbi(main.idaptik_ums_add_dog, c.idaptik_ums_add_dog);
    try expectFunctionAbi(main.idaptik_ums_add_drone, c.idaptik_ums_add_drone);
    try expectFunctionAbi(main.idaptik_ums_set_mission, c.idaptik_ums_set_mission);
    try expectFunctionAbi(main.idaptik_ums_set_physical, c.idaptik_ums_set_physical);
    try expectFunctionAbi(main.idaptik_ums_validate_level, c.idaptik_ums_validate_level);
    try expectFunctionAbi(main.idaptik_ums_serialize_level, c.idaptik_ums_serialize_level);
    try expectFunctionAbi(main.idaptik_ums_deserialize_level, c.idaptik_ums_deserialize_level);
    try expectFunctionAbi(main.idaptik_ums_admit_level_json, c.idaptik_ums_admit_level_json);
    try expectFunctionAbi(inventory.idaptik_ums_add_item, c.idaptik_ums_add_item);
    try expectFunctionAbi(inventory.idaptik_ums_add_assassin, c.idaptik_ums_add_assassin);
    try expectFunctionAbi(inventory.idaptik_ums_total_item_weight, c.idaptik_ums_total_item_weight);
    try expectFunctionAbi(inventory.idaptik_ums_count_items_by_kind, c.idaptik_ums_count_items_by_kind);
    try expectFunctionAbi(inventory.idaptik_ums_get_item, c.idaptik_ums_get_item);
    try expectFunctionAbi(inventory.idaptik_ums_degrade_condition, c.idaptik_ums_degrade_condition);
    try expectFunctionAbi(enemies.idaptik_ums_total_enemy_count, c.idaptik_ums_total_enemy_count);
    try expectFunctionAbi(enemies.idaptik_ums_threat_score, c.idaptik_ums_threat_score);
    try expectFunctionAbi(enemies.idaptik_ums_guards_in_zone, c.idaptik_ums_guards_in_zone);
    try expectFunctionAbi(enemies.idaptik_ums_enemies_in_range, c.idaptik_ums_enemies_in_range);
    try expectFunctionAbi(enemies.idaptik_ums_highest_guard_rank, c.idaptik_ums_highest_guard_rank);
    try expectFunctionAbi(enemies.idaptik_ums_add_device_defence, c.idaptik_ums_add_device_defence);
    try expectFunctionAbi(enemies.idaptik_ums_add_zone_transition, c.idaptik_ums_add_zone_transition);
    try expectFunctionAbi(mission_ffi.idaptik_ums_add_objective, c.idaptik_ums_add_objective);
    try expectFunctionAbi(mission_ffi.idaptik_ums_reset_objectives, c.idaptik_ums_reset_objectives);
    try expectFunctionAbi(mission_ffi.idaptik_ums_required_objective_count, c.idaptik_ums_required_objective_count);
    try expectFunctionAbi(mission_ffi.idaptik_ums_total_objective_count, c.idaptik_ums_total_objective_count);
    try expectFunctionAbi(mission_ffi.idaptik_ums_has_time_limit, c.idaptik_ums_has_time_limit);
    try expectFunctionAbi(mission_ffi.idaptik_ums_get_time_limit, c.idaptik_ums_get_time_limit);
    try expectFunctionAbi(mission_ffi.idaptik_ums_get_objective, c.idaptik_ums_get_objective);
    try expectFunctionAbi(wiring.idaptik_ums_add_wiring, c.idaptik_ums_add_wiring);
    try expectFunctionAbi(wiring.idaptik_ums_count_wiring_by_type, c.idaptik_ums_count_wiring_by_type);
    try expectFunctionAbi(wiring.idaptik_ums_wiring_at_device, c.idaptik_ums_wiring_at_device);
    try expectFunctionAbi(wiring.idaptik_ums_max_wiring_difficulty, c.idaptik_ums_max_wiring_difficulty);
    try expectFunctionAbi(wiring.idaptik_ums_avg_wiring_difficulty, c.idaptik_ums_avg_wiring_difficulty);
    try expectFunctionAbi(wiring.idaptik_ums_get_wiring, c.idaptik_ums_get_wiring);
}

test "generated Idris2 C header proven multiplayer and game-system signatures are ABI-compatible" {
    try expectFunctionAbi(proven_bridge.idaptik_safe_add, c.idaptik_safe_add);
    try expectFunctionAbi(proven_bridge.idaptik_safe_sub, c.idaptik_safe_sub);
    try expectFunctionAbi(proven_bridge.idaptik_safe_mul, c.idaptik_safe_mul);
    try expectFunctionAbi(proven_bridge.idaptik_safe_clamp, c.idaptik_safe_clamp);
    try expectFunctionAbi(proven_bridge.idaptik_safe_percentage, c.idaptik_safe_percentage);
    try expectFunctionAbi(proven_bridge.idaptik_safe_strlen, c.idaptik_safe_strlen);
    try expectFunctionAbi(proven_bridge.idaptik_safe_is_printable_ascii, c.idaptik_safe_is_printable_ascii);
    try expectFunctionAbi(proven_bridge.idaptik_safe_token_compare, c.idaptik_safe_token_compare);
    try expectFunctionAbi(proven_bridge.idaptik_classify_keystroke, c.idaptik_classify_keystroke);
    try expectFunctionAbi(multiplayer.idaptik_mp_roles_disjoint, c.idaptik_mp_roles_disjoint);
    try expectFunctionAbi(multiplayer.idaptik_mp_valid_role, c.idaptik_mp_valid_role);
    try expectFunctionAbi(multiplayer.idaptik_mp_alert_lte, c.idaptik_mp_alert_lte);
    try expectFunctionAbi(multiplayer.idaptik_mp_alert_max, c.idaptik_mp_alert_max);
    try expectFunctionAbi(multiplayer.idaptik_mp_alert_escalate, c.idaptik_mp_alert_escalate);
    try expectFunctionAbi(multiplayer.idaptik_mp_add_player, c.idaptik_mp_add_player);
    try expectFunctionAbi(multiplayer.idaptik_mp_count_role, c.idaptik_mp_count_role);
    try expectFunctionAbi(multiplayer.idaptik_mp_can_start, c.idaptik_mp_can_start);
    try expectFunctionAbi(multiplayer.idaptik_mp_valid_transition, c.idaptik_mp_valid_transition);
    try expectFunctionAbi(game_systems.idaptik_gs_apply_damage, c.idaptik_gs_apply_damage);
    try expectFunctionAbi(game_systems.idaptik_gs_heal, c.idaptik_gs_heal);
    try expectFunctionAbi(game_systems.idaptik_gs_is_alive, c.idaptik_gs_is_alive);
    try expectFunctionAbi(game_systems.idaptik_gs_resolve_critical, c.idaptik_gs_resolve_critical);
    try expectFunctionAbi(game_systems.idaptik_gs_add_detection, c.idaptik_gs_add_detection);
    try expectFunctionAbi(game_systems.idaptik_gs_alert_level_from_score, c.idaptik_gs_alert_level_from_score);
    try expectFunctionAbi(game_systems.idaptik_gs_skill_check, c.idaptik_gs_skill_check);
    try expectFunctionAbi(game_systems.idaptik_gs_subclass_bonus, c.idaptik_gs_subclass_bonus);
    try expectFunctionAbi(game_systems.idaptik_gs_valid_loadout_slot, c.idaptik_gs_valid_loadout_slot);
    try expectFunctionAbi(game_systems.idaptik_gs_valid_deck_capacity, c.idaptik_gs_valid_deck_capacity);
}

test "generated Idris2 C header IPC signatures are ABI-compatible" {
    try expectFunctionAbi(ipc_handlers.ipc_load_level, c.ipc_load_level);
    try expectFunctionAbi(ipc_handlers.ipc_save_level, c.ipc_save_level);
    try expectFunctionAbi(ipc_handlers.ipc_validate_level_abi, c.ipc_validate_level_abi);
    try expectFunctionAbi(ipc_handlers.ipc_list_levels, c.ipc_list_levels);
    try expectFunctionAbi(ipc_handlers.ipc_export_level_config, c.ipc_export_level_config);
    try expectFunctionAbi(ipc_handlers.ipc_get_system_info, c.ipc_get_system_info);
    try expectFunctionAbi(ipc_handlers.ipc_create_level, c.ipc_create_level);
    try expectFunctionAbi(ipc_handlers.ipc_destroy_level, c.ipc_destroy_level);
    try expectFunctionAbi(ipc_handlers.ipc_add_zone, c.ipc_add_zone);
    try expectFunctionAbi(ipc_handlers.ipc_add_device, c.ipc_add_device);
    try expectFunctionAbi(ipc_handlers.ipc_add_guard, c.ipc_add_guard);
    try expectFunctionAbi(ipc_handlers.ipc_add_dog, c.ipc_add_dog);
    try expectFunctionAbi(ipc_handlers.ipc_add_drone, c.ipc_add_drone);
    try expectFunctionAbi(ipc_handlers.ipc_set_mission, c.ipc_set_mission);
    try expectFunctionAbi(ipc_handlers.ipc_set_physical, c.ipc_set_physical);
    try expectFunctionAbi(ipc_handlers.ipc_validate_level, c.ipc_validate_level);
    try expectFunctionAbi(ipc_handlers.ipc_serialize_level, c.ipc_serialize_level);
    try expectFunctionAbi(ipc_handlers.ipc_deserialize_level, c.ipc_deserialize_level);
}

test "C JSON deserializer rejects unrepresentable documents" {
    const missing_mission =
        \\{"physical":{"ground_y":0,"world_width":1,"interaction_distance":1,"has_power_system":false,"has_security_cameras":false,"covert_links":0}}
    ;
    try std.testing.expect(main.idaptik_ums_deserialize_level(missing_mission.ptr, missing_mission.len) == null);

    const malformed_ip =
        \\{"devices":[{"kind":"server","ip":"10.0.0.999","name":"bad","security":"strong"}],"mission":{"mission_id":"m","location_id":"l"},"physical":{"ground_y":0,"world_width":1,"interaction_distance":1,"has_power_system":false,"has_security_cameras":false,"covert_links":0}}
    ;
    try std.testing.expect(main.idaptik_ums_deserialize_level(malformed_ip.ptr, malformed_ip.len) == null);
}

// =========================================================================
// Test: full lifecycle — create, populate, validate, serialise
// =========================================================================

test "full lifecycle: build a valid level" {
    const level = createTestLevel();
    defer main.idaptik_ums_destroy_level(level);

    // 1. Add devices.
    const server = types.DeviceSpec{
        .kind = .server,
        .ip = types.IpAddress.init(10, 0, 1, 1),
        .name = "db-server",
        .security = .strong,
    };
    const router = types.DeviceSpec{
        .kind = .router,
        .ip = types.IpAddress.init(10, 0, 1, 254),
        .name = "core-router",
        .security = .medium,
    };
    const pbx = types.DeviceSpec{
        .kind = .phone_system,
        .ip = types.IpAddress.init(10, 0, 1, 10),
        .name = "pbx-main",
        .security = .weak,
    };
    try std.testing.expect(main.idaptik_ums_add_device(level, &server));
    try std.testing.expect(main.idaptik_ums_add_device(level, &router));
    try std.testing.expect(main.idaptik_ums_add_device(level, &pbx));

    // 2. Add zones.
    const lobby = types.Zone{ .name = "lobby", .security_tier = 1 };
    const server_room = types.Zone{ .name = "server-room", .security_tier = 3 };
    try std.testing.expect(main.idaptik_ums_add_zone(level, &lobby));
    try std.testing.expect(main.idaptik_ums_add_zone(level, &server_room));

    // 3. Add guards in valid zones.
    const g1 = types.GuardPlacement{
        .world_x = .{ .position = 100.0 },
        .zone = "lobby",
        .rank = .basic_guard,
        .patrol_radius = 20.0,
    };
    const g2 = types.GuardPlacement{
        .world_x = .{ .position = 400.0 },
        .zone = "server-room",
        .rank = .elite_guard,
        .patrol_radius = 10.0,
    };
    try std.testing.expect(main.idaptik_ums_add_guard(level, &g1));
    try std.testing.expect(main.idaptik_ums_add_guard(level, &g2));

    // 4. Add a dog and a drone.
    const dog = types.DogPlacement{
        .world_x = .{ .position = 150.0 },
        .breed = .patrol,
        .patrol_radius = 30.0,
    };
    const drone = types.DronePlacement{
        .world_x = .{ .position = 250.0 },
        .archetype = .helper,
        .altitude = 5.0,
    };
    try std.testing.expect(main.idaptik_ums_add_dog(level, &dog));
    try std.testing.expect(main.idaptik_ums_add_drone(level, &drone));

    // 5. Set mission.
    const mission = types.MissionConfig{
        .mission_id = "m-alpha",
        .location_id = "data-centre-alpha",
        .objectives = null,
        .objectives_len = 0,
        .has_time_limit = true,
        .time_limit = 900,
    };
    try std.testing.expect(main.idaptik_ums_set_mission(level, &mission));

    // 6. Set physical.
    const physical = types.PhysicalConfig{
        .ground_y = 0.0,
        .world_width = 5000.0,
        .interaction_distance = 2.5,
        .has_power_system = true,
        .has_security_cameras = true,
        .number_of_covert_links = 2,
    };
    try std.testing.expect(main.idaptik_ums_set_physical(level, &physical));

    // 7. Set ordered zone transitions.
    level.zone_transitions[0] = .{
        .world_x = .{ .position = 300.0 },
        .from_zone = "lobby",
        .to_zone = "server-room",
    };
    level.zone_transitions_len = 1;

    // 8. Enable PBX with a matching device.
    level.has_pbx = true;
    level.pbx_ip = types.IpAddress.init(10, 0, 1, 10);
    level.pbx_world_x = .{ .position = 200.0 };

    // 9. Add a defence config referencing a real device.
    level.device_defences[0] = .{
        .ip = types.IpAddress.init(10, 0, 1, 1),
        .flags = std.mem.zeroes(types.DefenceFlags),
    };
    level.device_defences_len = 1;

    // 10. Validate — should pass all checks.
    const result = main.idaptik_ums_validate_level(level);
    try std.testing.expect(result.valid);
    try std.testing.expect(result.defence_targets_valid);
    try std.testing.expect(result.guards_in_zones);
    try std.testing.expect(result.zones_ordered);
    try std.testing.expect(result.pbx_consistent);

    // 11. Serialise.
    var buf: [16384]u8 = undefined;
    const written = main.idaptik_ums_serialize_level(level, &buf, buf.len);
    try std.testing.expect(written > 0);
}

// =========================================================================
// Test: validate_level with null returns all-false
// =========================================================================

test "validate_level with null returns all-false" {
    const result = main.idaptik_ums_validate_level(null);
    try std.testing.expect(!result.valid);
    try std.testing.expect(!result.defence_targets_valid);
    try std.testing.expect(!result.guards_in_zones);
    try std.testing.expect(!result.zones_ordered);
    try std.testing.expect(!result.pbx_consistent);
}
