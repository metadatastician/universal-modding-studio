-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Authoritative C representation of the bounded LevelData ABI.
|||
||| Idris2 0.7 has no C-header backend.  This module therefore follows the
||| estate's enaction-engine pattern: a total Idris2 program renders a header
||| from a typechecked declaration model.  The generated header is subsequently
||| checked against Zig's extern layouts; typechecking this renderer alone is
||| not a proof that a C compiler and Zig choose identical layouts.
module CABI

import Data.List
import System

%default total

data CType
  = CVoid | CBool | CU8 | CU32 | CSize | CF64 | CChar | CStringArray
  | CNamed String
  | CConstPtr CType
  | CMutPtr CType
  | CArray Nat CType

record Field where
  constructor MkField
  fieldType : CType
  fieldName : String

record StructDecl where
  constructor MkStruct
  structName : String
  fields : List Field

record Parameter where
  constructor MkParameter
  parameterType : CType
  parameterName : String

record FunctionDecl where
  constructor MkFunction
  returnType : CType
  functionName : String
  functionParameters : List Parameter

renderType : CType -> String
renderType CVoid = "void"
renderType CBool = "bool"
renderType CU8 = "uint8_t"
renderType CU32 = "uint32_t"
renderType CSize = "size_t"
renderType CF64 = "double"
renderType CChar = "char"
renderType CStringArray = "const char *const *"
renderType (CNamed name) = name
renderType (CConstPtr ty) = "const " ++ renderType ty ++ " *"
renderType (CMutPtr ty) = renderType ty ++ " *"
renderType (CArray _ ty) = renderType ty

renderField : Field -> String
renderField (MkField (CArray count ty) name) =
  "  " ++ renderType ty ++ " " ++ name ++ "[" ++ show count ++ "];\n"
renderField (MkField ty name) = "  " ++ renderType ty ++ " " ++ name ++ ";\n"

renderStruct : StructDecl -> String
renderStruct (MkStruct name fields) =
  "typedef struct " ++ name ++ " {\n" ++
  concat (map renderField fields) ++
  "} " ++ name ++ ";\n\n"

renderParameter : Parameter -> String
renderParameter (MkParameter ty name) = renderType ty ++ " " ++ name

renderFunction : FunctionDecl -> String
renderFunction (MkFunction ret name []) =
  renderType ret ++ " " ++ name ++ "(void);\n"
renderFunction (MkFunction ret name params) =
  renderType ret ++ " " ++ name ++ "(" ++
  concat (intersperse ", " (map renderParameter params)) ++ ");\n"

named : String -> CType
named = CNamed

field : CType -> String -> Field
field = MkField

array : Nat -> CType -> CType
array = CArray

ptr : CType -> CType
ptr = CMutPtr

constPtr : CType -> CType
constPtr = CConstPtr

param : CType -> String -> Parameter
param = MkParameter

private
u8Aliases : List String
u8Aliases =
  [ "ums_security_level", "ums_device_kind", "ums_guard_rank"
  , "ums_dog_breed", "ums_drone_archetype", "ums_alert_level"
  , "ums_item_condition", "ums_cable_type", "ums_adapter_type"
  , "ums_tool_type", "ums_module_type", "ums_consumable_type"
  , "ums_item_kind_tag", "ums_wiring_type", "ums_validation_check"
  ]

private
aliasDeclarations : String
aliasDeclarations = concat (map (\name => "typedef uint8_t " ++ name ++ ";\n") u8Aliases) ++ "\n"

private
enumConstants : List (String, Nat)
enumConstants =
  [ ("UMS_SECURITY_OPEN", 0), ("UMS_SECURITY_WEAK", 1)
  , ("UMS_SECURITY_MEDIUM", 2), ("UMS_SECURITY_STRONG", 3)
  , ("UMS_DEVICE_LAPTOP", 0), ("UMS_DEVICE_DESKTOP", 1), ("UMS_DEVICE_SERVER", 2)
  , ("UMS_DEVICE_ROUTER", 3), ("UMS_DEVICE_SWITCH", 4), ("UMS_DEVICE_FIREWALL", 5)
  , ("UMS_DEVICE_CAMERA", 6), ("UMS_DEVICE_ACCESS_POINT", 7), ("UMS_DEVICE_PATCH_PANEL", 8)
  , ("UMS_DEVICE_POWER_SUPPLY", 9), ("UMS_DEVICE_PHONE_SYSTEM", 10), ("UMS_DEVICE_FIBRE_HUB", 11)
  , ("UMS_GUARD_BASIC", 0), ("UMS_GUARD_ENFORCER", 1), ("UMS_GUARD_ANTI_HACKER", 2)
  , ("UMS_GUARD_SENTINEL", 3), ("UMS_GUARD_ASSASSIN", 4), ("UMS_GUARD_ELITE", 5)
  , ("UMS_GUARD_SECURITY_CHIEF", 6), ("UMS_GUARD_RIVAL_HACKER", 7)
  , ("UMS_DOG_PATROL", 0), ("UMS_DOG_BLOODHOUND", 1), ("UMS_DOG_ROBO", 2)
  , ("UMS_DRONE_HELPER", 0), ("UMS_DRONE_HUNTER", 1), ("UMS_DRONE_KILLER", 2)
  , ("UMS_ALERT_GREEN", 0), ("UMS_ALERT_YELLOW", 1), ("UMS_ALERT_ORANGE", 2), ("UMS_ALERT_RED", 3)
  , ("UMS_CONDITION_PRISTINE", 0), ("UMS_CONDITION_GOOD", 1), ("UMS_CONDITION_WORN", 2)
  , ("UMS_CONDITION_DAMAGED", 3), ("UMS_CONDITION_BROKEN", 4)
  , ("UMS_CABLE_ETHERNET", 0), ("UMS_CABLE_FIBRE_LC", 1), ("UMS_CABLE_FIBRE_SC", 2)
  , ("UMS_CABLE_SERIAL", 3), ("UMS_CABLE_USB", 4), ("UMS_CABLE_UNIVERSAL", 5)
  , ("UMS_ADAPTER_ETHERNET_TO_FIBRE", 0), ("UMS_ADAPTER_USB_TO_SERIAL", 1), ("UMS_ADAPTER_MEDIA_CONVERTER", 2)
  , ("UMS_TOOL_CRIMPER", 0), ("UMS_TOOL_SPLICER", 1), ("UMS_TOOL_MULTIMETER", 2)
  , ("UMS_TOOL_WIRE_CUTTER", 3), ("UMS_TOOL_DEBUGGER", 4)
  , ("UMS_MODULE_SFP", 0), ("UMS_MODULE_GBIC", 1), ("UMS_MODULE_QSFP", 2), ("UMS_MODULE_TRANSCEIVER", 3)
  , ("UMS_CONSUMABLE_BATTERY_PACK", 0), ("UMS_CONSUMABLE_EMP", 1)
  , ("UMS_CONSUMABLE_SMOKE_GRENADE", 2), ("UMS_CONSUMABLE_DECRYPTOR", 3)
  , ("UMS_ITEM_KIND_CABLE", 0), ("UMS_ITEM_KIND_ADAPTER", 1), ("UMS_ITEM_KIND_TOOL", 2)
  , ("UMS_ITEM_KIND_MODULE", 3), ("UMS_ITEM_KIND_STORAGE", 4), ("UMS_ITEM_KIND_CONSUMABLE", 5)
  , ("UMS_ITEM_KIND_KEYCARD", 6), ("UMS_ITEM_KIND_RADIO", 7)
  , ("UMS_WIRING_PATCH_PANEL", 0), ("UMS_WIRING_SWITCH_BACKPLANE", 1)
  , ("UMS_WIRING_SERVER_RACK", 2), ("UMS_WIRING_FIBRE_SPLICING", 3), ("UMS_WIRING_PBX_COMMS", 4)
  , ("UMS_VALIDATION_DEFENCE_TARGETS", 0), ("UMS_VALIDATION_GUARDS_IN_ZONES", 1)
  , ("UMS_VALIDATION_ZONES_ORDERED", 2), ("UMS_VALIDATION_PBX_CONSISTENT", 3)
  ]

private
renderConstant : (String, Nat) -> String
renderConstant (name, value) = "#define " ++ name ++ " " ++ show value ++ "u\n"

private
enumConstantDeclarations : String
enumConstantDeclarations = concat (map renderConstant enumConstants) ++ "\n"

private maxDevices, maxZones, maxGuards, maxDogs, maxDrones : Nat
maxDevices = 256
maxZones = 64
maxGuards = 128
maxDogs = 64
maxDrones = 64

private maxAssassins, maxItems, maxWiring, maxZoneTransitions : Nat
maxAssassins = 16
maxItems = 512
maxWiring = 128
maxZoneTransitions = 64

private maxDeviceDefences, maxObjectives : Nat
maxDeviceDefences = 256
maxObjectives = 32

private
capacityDeclarations : String
capacityDeclarations = concat (map renderConstant capacities) ++ "\n"
  where
    capacities : List (String, Nat)
    capacities =
      [ ("UMS_MAX_DEVICES", maxDevices), ("UMS_MAX_ZONES", maxZones)
      , ("UMS_MAX_GUARDS", maxGuards), ("UMS_MAX_DOGS", maxDogs)
      , ("UMS_MAX_DRONES", maxDrones), ("UMS_MAX_ASSASSINS", maxAssassins)
      , ("UMS_MAX_ITEMS", maxItems), ("UMS_MAX_WIRING", maxWiring)
      , ("UMS_MAX_ZONE_TRANSITIONS", maxZoneTransitions)
      , ("UMS_MAX_DEVICE_DEFENCES", maxDeviceDefences)
      , ("UMS_MAX_OBJECTIVES", maxObjectives)
      ]

private
structs : List StructDecl
structs =
  [ MkStruct "ums_ip_address"
      [ field CU8 "octet1", field CU8 "octet2", field CU8 "octet3", field CU8 "octet4" ]
  , MkStruct "ums_percentage" [ field CU8 "value" ]
  , MkStruct "ums_world_x" [ field CF64 "position" ]
  , MkStruct "ums_item_kind"
      [ field (named "ums_item_kind_tag") "tag", field CU8 "sub_type"
      , field CU32 "capacity", field (constPtr CChar) "zone_name" ]
  , MkStruct "ums_device_spec"
      [ field (named "ums_device_kind") "kind"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field (named "ums_ip_address") "ip", field (constPtr CChar) "name"
      , field (named "ums_security_level") "security"
      , field CU8 "_pad3", field CU8 "_pad4", field CU8 "_pad5" ]
  , MkStruct "ums_optional_ip_address"
      [ field CBool "has_value", field (named "ums_ip_address") "ip" ]
  , MkStruct "ums_defence_flags"
      [ field CBool "tamper_proof", field CBool "decoy", field CBool "canary"
      , field CBool "one_way_mirror", field CBool "kill_switch"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field (named "ums_optional_ip_address") "failover_target"
      , field (named "ums_optional_ip_address") "cascade_trap"
      , field (named "ums_optional_ip_address") "mirror_target"
      , field CStringArray "instruction_whitelist"
      , field CBool "has_time_bomb"
      , field CU8 "_pad3", field CU8 "_pad4", field CU8 "_pad5"
      , field CU32 "time_bomb", field CBool "has_undo_immunity"
      , field CU8 "_pad6", field CU8 "_pad7", field CU8 "_pad8"
      , field CU32 "undo_immunity" ]
  , MkStruct "ums_device_defence_config"
      [ field (named "ums_ip_address") "ip", field (named "ums_defence_flags") "flags" ]
  , MkStruct "ums_zone"
      [ field (constPtr CChar) "name", field CU32 "security_tier" ]
  , MkStruct "ums_zone_transition"
      [ field (named "ums_world_x") "world_x", field (constPtr CChar) "from_zone"
      , field (constPtr CChar) "to_zone" ]
  , MkStruct "ums_item"
      [ field (constPtr CChar) "id", field (named "ums_item_kind") "kind"
      , field (constPtr CChar) "name", field CU32 "weight"
      , field (named "ums_item_condition") "condition", field CBool "has_uses_remaining"
      , field CU8 "_pad0", field CU8 "_pad1", field CU32 "uses_remaining" ]
  , MkStruct "ums_world_item"
      [ field (named "ums_item") "item", field (named "ums_world_x") "world_x"
      , field (constPtr CChar) "container" ]
  , MkStruct "ums_guard_placement"
      [ field (named "ums_world_x") "world_x", field (constPtr CChar) "zone"
      , field (named "ums_guard_rank") "rank"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2", field CU8 "_pad3"
      , field CU8 "_pad4", field CU8 "_pad5", field CU8 "_pad6"
      , field CF64 "patrol_radius" ]
  , MkStruct "ums_dog_placement"
      [ field (named "ums_world_x") "world_x", field (named "ums_dog_breed") "breed"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2", field CU8 "_pad3"
      , field CU8 "_pad4", field CU8 "_pad5", field CU8 "_pad6"
      , field CF64 "patrol_radius" ]
  , MkStruct "ums_drone_placement"
      [ field (named "ums_world_x") "world_x", field (named "ums_drone_archetype") "archetype"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2", field CU8 "_pad3"
      , field CU8 "_pad4", field CU8 "_pad5", field CU8 "_pad6", field CF64 "altitude" ]
  , MkStruct "ums_assassin_config"
      [ field (named "ums_world_x") "spawn_x", field CU32 "ambush_count"
      , field CU32 "retreat_threshold" ]
  , MkStruct "ums_mission_objective"
      [ field (constPtr CChar) "id", field (constPtr CChar) "description", field CBool "required"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2", field CU8 "_pad3"
      , field CU8 "_pad4", field CU8 "_pad5", field CU8 "_pad6" ]
  , MkStruct "ums_mission_config"
      [ field (constPtr CChar) "mission_id", field (constPtr CChar) "location_id"
      , field (constPtr (named "ums_mission_objective")) "objectives"
      , field CU32 "objectives_len", field CBool "has_time_limit"
      , field CU8 "_pad0", field CU8 "_pad1", field CU32 "time_limit" ]
  , MkStruct "ums_wiring_challenge"
      [ field (named "ums_wiring_type") "kind"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field (named "ums_ip_address") "device_ip", field CU32 "difficulty" ]
  , MkStruct "ums_physical_config"
      [ field CF64 "ground_y", field CF64 "world_width", field CF64 "interaction_distance"
      , field CBool "has_power_system", field CBool "has_security_cameras"
      , field CU8 "_pad0", field CU8 "_pad1", field CU32 "number_of_covert_links" ]
  , MkStruct "ums_level_data"
      [ field (array maxDevices (named "ums_device_spec")) "devices", field CU32 "devices_len"
      , field (array maxZones (named "ums_zone")) "zones", field CU32 "zones_len"
      , field (array maxGuards (named "ums_guard_placement")) "guards", field CU32 "guards_len"
      , field (array maxDogs (named "ums_dog_placement")) "dogs", field CU32 "dogs_len"
      , field (array maxDrones (named "ums_drone_placement")) "drones", field CU32 "drones_len"
      , field (array maxAssassins (named "ums_assassin_config")) "assassins", field CU32 "assassins_len"
      , field (array maxItems (named "ums_world_item")) "items", field CU32 "items_len"
      , field (array maxWiring (named "ums_wiring_challenge")) "wiring", field CU32 "wiring_len"
      , field (named "ums_mission_config") "mission", field (named "ums_physical_config") "physical"
      , field (array maxZoneTransitions (named "ums_zone_transition")) "zone_transitions"
      , field CU32 "zone_transitions_len"
      , field (array maxDeviceDefences (named "ums_device_defence_config")) "device_defences"
      , field CU32 "device_defences_len", field CBool "has_pbx"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field (named "ums_ip_address") "pbx_ip", field (named "ums_world_x") "pbx_world_x" ]
  , MkStruct "ums_validation_result"
      [ field CBool "valid", field CBool "defence_targets_valid", field CBool "guards_in_zones"
      , field CBool "zones_ordered", field CBool "pbx_consistent"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2" ]
  ]

private
levelPtr : CType
levelPtr = ptr (named "ums_level_data")

private
constLevelPtr : CType
constLevelPtr = constPtr (named "ums_level_data")

private
functions : List FunctionDecl
functions =
  [ MkFunction levelPtr "idaptik_ums_create_level" []
  , MkFunction CVoid "idaptik_ums_destroy_level" [param levelPtr "level"]
  , MkFunction CBool "idaptik_ums_add_device" [param levelPtr "level", param (constPtr (named "ums_device_spec")) "spec"]
  , MkFunction CBool "idaptik_ums_add_zone" [param levelPtr "level", param (constPtr (named "ums_zone")) "zone"]
  , MkFunction CBool "idaptik_ums_add_guard" [param levelPtr "level", param (constPtr (named "ums_guard_placement")) "guard"]
  , MkFunction CBool "idaptik_ums_add_dog" [param levelPtr "level", param (constPtr (named "ums_dog_placement")) "dog"]
  , MkFunction CBool "idaptik_ums_add_drone" [param levelPtr "level", param (constPtr (named "ums_drone_placement")) "drone"]
  , MkFunction CBool "idaptik_ums_set_mission" [param levelPtr "level", param (constPtr (named "ums_mission_config")) "mission"]
  , MkFunction CBool "idaptik_ums_set_physical" [param levelPtr "level", param (constPtr (named "ums_physical_config")) "physical"]
  , MkFunction (named "ums_validation_result") "idaptik_ums_validate_level" [param constLevelPtr "level"]
  , MkFunction CSize "idaptik_ums_serialize_level" [param constLevelPtr "level", param (ptr CU8) "buf", param CSize "buf_len"]
  , MkFunction levelPtr "idaptik_ums_deserialize_level" [param (constPtr CU8) "data", param CSize "data_len"]
  , MkFunction CBool "idaptik_ums_admit_level_json" [param (constPtr CU8) "data", param CSize "data_len"]
  ]

public export
cHeader : String
cHeader =
  "/* SPDX-License-Identifier: AGPL-3.0-or-later */\n" ++
  "/* SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> */\n" ++
  "/* Generated by the typechecked Idris2 CABI module. DO NOT EDIT. */\n" ++
  "#ifndef IDAPTIK_UMS_LEVEL_H\n#define IDAPTIK_UMS_LEVEL_H\n\n" ++
  "#include <stdbool.h>\n#include <stddef.h>\n#include <stdint.h>\n\n" ++
  "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n" ++
  capacityDeclarations ++ aliasDeclarations ++ enumConstantDeclarations ++ concat (map renderStruct structs) ++
  concat (map renderFunction functions) ++
  "\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n"

usage : IO ()
usage = putStrLn "usage: idaptik-ums-abi-gen c"

main : IO ()
main = do
  args <- getArgs
  case args of
    [_, "c"] => putStr cHeader
    _ => usage
