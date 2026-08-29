// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Bounded JSON admission companion to ProvenBridge.parseValidatedLevelJson.
// This parser consumes the same snake_case wire representation and applies
// the same four cross-domain admission conditions. It deliberately validates
// every LevelData section, even though the older C-struct deserialiser is
// still partial and remains a separately recorded gap.

const std = @import("std");

pub const max_level_json_bytes: usize = 1024 * 1024;

pub const AdmissionError = error{
    InvalidJson,
    InvalidField,
    DefenceTargetsInvalid,
    GuardZoneInvalid,
    TransitionOrderInvalid,
    PbxInvalid,
};

const WireDevice = struct {
    kind: []const u8,
    ip: []const u8,
    name: []const u8,
    security: []const u8,
};

const WireZone = struct {
    name: []const u8,
    security_tier: u32,
};

const WireGuard = struct {
    world_x: f64,
    zone: []const u8,
    rank: []const u8,
    patrol_radius: f64,
};

const WireDog = struct {
    world_x: f64,
    breed: []const u8,
    patrol_radius: f64,
};

const WireDrone = struct {
    world_x: f64,
    archetype: []const u8,
    altitude: f64,
};

const WireAssassin = struct {
    spawn_x: f64,
    ambush_count: u32,
    retreat_threshold: u32,
};

const WireItemKind = struct {
    type: []const u8,
    sub_type: ?[]const u8 = null,
    capacity: ?u32 = null,
    zone: ?[]const u8 = null,
};

const WireItem = struct {
    id: []const u8,
    kind: WireItemKind,
    name: []const u8,
    weight: u32,
    condition: []const u8,
    uses_remaining: ?u32 = null,
};

const WireWorldItem = struct {
    item: WireItem,
    world_x: f64,
    container: []const u8,
};

const WireWiring = struct {
    kind: []const u8,
    device_ip: []const u8,
    difficulty: u32,
};

const WireObjective = struct {
    id: []const u8,
    description: []const u8,
    required: bool,
};

const WireMission = struct {
    mission_id: []const u8,
    location_id: []const u8,
    objectives: []const WireObjective = &.{},
    time_limit: ?u32 = null,
};

const WirePhysical = struct {
    ground_y: f64,
    world_width: f64,
    interaction_distance: f64,
    has_power_system: bool,
    has_security_cameras: bool,
    covert_links: u32,
};

const WireTransition = struct {
    world_x: f64,
    from_zone: []const u8,
    to_zone: []const u8,
};

const WireFlags = struct {
    tamper_proof: bool = false,
    decoy: bool = false,
    canary: bool = false,
    one_way_mirror: bool = false,
    kill_switch: bool = false,
    failover_target: ?[]const u8 = null,
    cascade_trap: ?[]const u8 = null,
    mirror_target: ?[]const u8 = null,
    instruction_whitelist: ?[]const []const u8 = null,
    time_bomb: ?u32 = null,
    undo_immunity: ?u32 = null,
};

const WireDefence = struct {
    ip: []const u8,
    flags: WireFlags = .{},
};

const WireLevel = struct {
    devices: []const WireDevice = &.{},
    zones: []const WireZone = &.{},
    guards: []const WireGuard = &.{},
    dogs: []const WireDog = &.{},
    drones: []const WireDrone = &.{},
    assassins: []const WireAssassin = &.{},
    items: []const WireWorldItem = &.{},
    wiring: []const WireWiring = &.{},
    mission: ?WireMission = null,
    physical: ?WirePhysical = null,
    zone_transitions: []const WireTransition = &.{},
    device_defences: []const WireDefence = &.{},
    has_pbx: bool = false,
    pbx_ip: []const u8 = "0.0.0.0",
    pbx_world_x: f64 = 0,
};

fn oneOf(value: []const u8, allowed: []const []const u8) bool {
    for (allowed) |candidate| {
        if (std.mem.eql(u8, value, candidate)) return true;
    }
    return false;
}

fn validIp(value: []const u8) bool {
    var parts = std.mem.splitScalar(u8, value, '.');
    var count: usize = 0;
    while (parts.next()) |part| {
        if (part.len == 0 or count == 4) return false;
        _ = std.fmt.parseInt(u8, part, 10) catch return false;
        count += 1;
    }
    return count == 4;
}

fn deviceIpExists(devices: []const WireDevice, needle: []const u8) bool {
    for (devices) |device| {
        if (std.mem.eql(u8, device.ip, needle)) return true;
    }
    return false;
}

fn zoneExists(zones: []const WireZone, needle: []const u8) bool {
    for (zones) |zone| {
        if (std.mem.eql(u8, zone.name, needle)) return true;
    }
    return false;
}

fn validateItemKind(kind: WireItemKind) bool {
    if (std.mem.eql(u8, kind.type, "cable"))
        return kind.sub_type != null and oneOf(kind.sub_type.?, &.{ "ethernet", "fibre_lc", "fibre_sc", "serial", "usb", "universal" });
    if (std.mem.eql(u8, kind.type, "adapter"))
        return kind.sub_type != null and oneOf(kind.sub_type.?, &.{ "ethernet_to_fibre", "usb_to_serial", "media_converter" });
    if (std.mem.eql(u8, kind.type, "tool"))
        return kind.sub_type != null and oneOf(kind.sub_type.?, &.{ "crimper", "splicer", "multimeter", "wire_cutter", "debugger" });
    if (std.mem.eql(u8, kind.type, "module"))
        return kind.sub_type != null and oneOf(kind.sub_type.?, &.{ "sfp", "gbic", "qsfp", "transceiver" });
    if (std.mem.eql(u8, kind.type, "consumable"))
        return kind.sub_type != null and oneOf(kind.sub_type.?, &.{ "battery_pack", "emp", "smoke_grenade", "decryptor" });
    if (std.mem.eql(u8, kind.type, "storage")) return kind.capacity != null;
    if (std.mem.eql(u8, kind.type, "keycard")) return kind.zone != null;
    return std.mem.eql(u8, kind.type, "radio");
}

fn validateRepresentation(level: WireLevel) AdmissionError!void {
    if (level.devices.len > 256 or level.zones.len > 64 or level.guards.len > 128 or
        level.dogs.len > 64 or level.drones.len > 64 or level.assassins.len > 16 or
        level.items.len > 512 or level.wiring.len > 128 or
        level.zone_transitions.len > 64 or level.device_defences.len > 256)
        return error.InvalidField;

    for (level.devices) |device| {
        if (!oneOf(device.kind, &.{ "laptop", "desktop", "server", "router", "switch", "firewall", "camera", "access_point", "patch_panel", "power_supply", "phone_system", "fibre_hub" }) or
            !validIp(device.ip) or device.name.len == 0 or
            !oneOf(device.security, &.{ "open", "weak", "medium", "strong" }))
            return error.InvalidField;
    }
    for (level.zones) |zone| if (zone.name.len == 0) return error.InvalidField;
    for (level.guards) |guard| {
        if (guard.zone.len == 0 or !oneOf(guard.rank, &.{ "basic", "enforcer", "anti_hacker", "sentinel", "assassin", "elite", "chief", "rival_hacker" }))
            return error.InvalidField;
    }
    for (level.dogs) |dog| if (!oneOf(dog.breed, &.{ "patrol", "bloodhound", "robo_dog" })) return error.InvalidField;
    for (level.drones) |drone| if (!oneOf(drone.archetype, &.{ "helper", "hunter", "killer" })) return error.InvalidField;
    for (level.items) |world_item| {
        if (world_item.item.id.len == 0 or world_item.item.name.len == 0 or
            world_item.container.len == 0 or !validateItemKind(world_item.item.kind) or
            !oneOf(world_item.item.condition, &.{ "pristine", "good", "worn", "damaged", "broken" }))
            return error.InvalidField;
    }
    for (level.wiring) |wiring| {
        if (!oneOf(wiring.kind, &.{ "patch_panel", "switch_backplane", "server_rack", "fibre_splicing", "pbx_comms" }) or !validIp(wiring.device_ip))
            return error.InvalidField;
    }
    if (level.mission) |mission| {
        if (mission.mission_id.len == 0 or mission.location_id.len == 0 or mission.objectives.len > 32)
            return error.InvalidField;
        for (mission.objectives) |objective| {
            if (objective.id.len == 0 or objective.description.len == 0) return error.InvalidField;
        }
    }
    for (level.zone_transitions) |transition| {
        if (transition.from_zone.len == 0 or transition.to_zone.len == 0) return error.InvalidField;
    }
    for (level.device_defences) |defence| {
        if (!validIp(defence.ip)) return error.InvalidField;
        for ([_]?[]const u8{ defence.flags.failover_target, defence.flags.cascade_trap, defence.flags.mirror_target }) |target| {
            if (target) |ip| if (!validIp(ip)) return error.InvalidField;
        }
        if (defence.flags.instruction_whitelist) |instructions| {
            for (instructions) |instruction| if (instruction.len == 0) return error.InvalidField;
        }
    }
    if (!validIp(level.pbx_ip)) return error.InvalidField;
    _ = level.physical;
    _ = level.pbx_world_x;
}

fn validateWitnesses(level: WireLevel) AdmissionError!void {
    for (level.device_defences) |defence| {
        if (!deviceIpExists(level.devices, defence.ip)) return error.DefenceTargetsInvalid;
        for ([_]?[]const u8{ defence.flags.failover_target, defence.flags.cascade_trap, defence.flags.mirror_target }) |target| {
            if (target) |ip| {
                if (!deviceIpExists(level.devices, ip)) return error.DefenceTargetsInvalid;
            }
        }
    }
    for (level.guards) |guard| {
        if (!zoneExists(level.zones, guard.zone)) return error.GuardZoneInvalid;
    }
    if (level.zone_transitions.len > 1) {
        var previous = level.zone_transitions[0].world_x;
        for (level.zone_transitions[1..]) |transition| {
            if (transition.world_x < previous) return error.TransitionOrderInvalid;
            previous = transition.world_x;
        }
    }
    if (level.has_pbx and !deviceIpExists(level.devices, level.pbx_ip)) return error.PbxInvalid;
}

/// Admit one bounded snake_case LevelData JSON document.
///
/// Success means the complete wire representation parsed and all four
/// cross-domain conditions matched the Idris2 admission semantics. It does
/// not claim that the legacy LevelData C-struct deserialiser is lossless.
pub fn admitLevelJson(allocator: std.mem.Allocator, input: []const u8) AdmissionError!void {
    if (input.len == 0 or input.len > max_level_json_bytes) return error.InvalidField;
    const parsed = std.json.parseFromSlice(WireLevel, allocator, input, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return error.InvalidJson;
    defer parsed.deinit();

    try validateRepresentation(parsed.value);
    try validateWitnesses(parsed.value);
}

test "shared fixture corpus matches Idris2 admission outcomes" {
    const accepted = @embedFile("../../../tests/abi-parity/valid-full-level.json");
    try admitLevelJson(std.testing.allocator, accepted);

    const rejected = [_][]const u8{
        @embedFile("../../../tests/abi-parity/reject-defence-target.json"),
        @embedFile("../../../tests/abi-parity/reject-guard-zone.json"),
        @embedFile("../../../tests/abi-parity/reject-transition-order.json"),
        @embedFile("../../../tests/abi-parity/reject-pbx.json"),
        @embedFile("../../../tests/abi-parity/reject-malformed-ip.json"),
    };
    for (rejected) |fixture| {
        _ = admitLevelJson(std.testing.allocator, fixture) catch continue;
        return error.TestUnexpectedResult;
    }
}
