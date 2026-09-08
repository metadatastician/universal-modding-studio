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
import Multiplayer
import GameSystems
import Representation

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
  , "ums_coop_role", "ums_connection_state", "ums_session_phase"
  , "ums_multiplayer_alert", "ums_sync_message_kind"
  , "ums_damage_type", "ums_critical_outcome", "ums_detection_source"
  , "ums_jessica_subclass", "ums_q_certification", "ums_loadout_slot"
  , "ums_attribute"
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
  , ("UMS_COOP_ROLE_JESSICA", cast (Multiplayer.coopRoleToInt Multiplayer.Jessica))
  , ("UMS_COOP_ROLE_Q_HACKER", cast (Multiplayer.coopRoleToInt Multiplayer.QHacker))
  , ("UMS_COOP_ROLE_OBSERVER", cast (Multiplayer.coopRoleToInt Multiplayer.Observer))
  , ("UMS_CONNECTION_OFFLINE", cast (Multiplayer.connectionStateToInt Multiplayer.Offline))
  , ("UMS_CONNECTION_CONNECTING", cast (Multiplayer.connectionStateToInt Multiplayer.Connecting))
  , ("UMS_CONNECTION_IN_LOBBY", cast (Multiplayer.connectionStateToInt Multiplayer.InLobby))
  , ("UMS_CONNECTION_IN_SESSION", cast (Multiplayer.connectionStateToInt Multiplayer.InSession))
  , ("UMS_SESSION_LOBBY", cast (Multiplayer.sessionPhaseToInt Multiplayer.Lobby))
  , ("UMS_SESSION_COUNTDOWN", cast (Multiplayer.sessionPhaseToInt Multiplayer.Countdown))
  , ("UMS_SESSION_LOADING", cast (Multiplayer.sessionPhaseToInt Multiplayer.Loading))
  , ("UMS_SESSION_PLAYING", cast (Multiplayer.sessionPhaseToInt Multiplayer.Playing))
  , ("UMS_SESSION_PAUSED", cast (Multiplayer.sessionPhaseToInt Multiplayer.Paused))
  , ("UMS_SESSION_COMPLETE", cast (Multiplayer.sessionPhaseToInt Multiplayer.Complete))
  , ("UMS_MP_ALERT_GREEN", cast (Multiplayer.alertToInt Multiplayer.AlertGreen))
  , ("UMS_MP_ALERT_YELLOW", cast (Multiplayer.alertToInt Multiplayer.AlertYellow))
  , ("UMS_MP_ALERT_ORANGE", cast (Multiplayer.alertToInt Multiplayer.AlertOrange))
  , ("UMS_MP_ALERT_RED", cast (Multiplayer.alertToInt Multiplayer.AlertRed))
  , ("UMS_SYNC_POSITION", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgPosition))
  , ("UMS_SYNC_VM_EXECUTE", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgVMExecute))
  , ("UMS_SYNC_VM_UNDO", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgVMUndo))
  , ("UMS_SYNC_VM_STATE", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgVMState))
  , ("UMS_SYNC_BEBOP_DISCOVERED", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgBebopDiscovered))
  , ("UMS_SYNC_BEBOP_ACTIVATED", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgBebopActivated))
  , ("UMS_SYNC_BEBOP_COOP_REQ", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgBebopCoopReq))
  , ("UMS_SYNC_BEBOP_COOP_ACCEPT", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgBebopCoopAccept))
  , ("UMS_SYNC_DEVICE_ACCESSED", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgDeviceAccessed))
  , ("UMS_SYNC_ALERT_CHANGED", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgAlertChanged))
  , ("UMS_SYNC_CHAT", cast (Multiplayer.syncMessageKindToInt Multiplayer.MsgChat))
  , ("UMS_DAMAGE_PHYSICAL", cast (GameSystems.damageTypeToInt GameSystems.PhysicalDamage))
  , ("UMS_DAMAGE_ELECTRIC", cast (GameSystems.damageTypeToInt GameSystems.ElectricDamage))
  , ("UMS_DAMAGE_CYBER", cast (GameSystems.damageTypeToInt GameSystems.CyberDamage))
  , ("UMS_DAMAGE_FALL", cast (GameSystems.damageTypeToInt GameSystems.FallDamage))
  , ("UMS_CRITICAL_FAILURE", cast (GameSystems.critOutcomeToInt GameSystems.CriticalFailure))
  , ("UMS_CRITICAL_NORMAL", cast (GameSystems.critOutcomeToInt GameSystems.NormalResult))
  , ("UMS_CRITICAL_SUCCESS", cast (GameSystems.critOutcomeToInt GameSystems.CriticalSuccess))
  , ("UMS_CRITICAL_PERFECT", cast (GameSystems.critOutcomeToInt GameSystems.PerfectExecution))
  , ("UMS_DETECTION_CAMERA", cast (GameSystems.detSourceToInt GameSystems.CameraDetected))
  , ("UMS_DETECTION_GUARD", cast (GameSystems.detSourceToInt GameSystems.GuardDetected))
  , ("UMS_DETECTION_DOG", cast (GameSystems.detSourceToInt GameSystems.DogDetected))
  , ("UMS_DETECTION_DRONE", cast (GameSystems.detSourceToInt GameSystems.DroneDetected))
  , ("UMS_DETECTION_ALARM", cast (GameSystems.detSourceToInt GameSystems.AlarmTriggered))
  , ("UMS_DETECTION_NOISE", cast (GameSystems.detSourceToInt GameSystems.NoiseDetected))
  , ("UMS_DETECTION_CYBER_TRACE", cast (GameSystems.detSourceToInt GameSystems.CyberTraceBack))
  , ("UMS_SUBCLASS_ASSAULT", cast (GameSystems.subclassToInt GameSystems.Assault))
  , ("UMS_SUBCLASS_RECON", cast (GameSystems.subclassToInt GameSystems.Recon))
  , ("UMS_SUBCLASS_ENGINEER", cast (GameSystems.subclassToInt GameSystems.Engineer))
  , ("UMS_SUBCLASS_SIGNALS", cast (GameSystems.subclassToInt GameSystems.Signals))
  , ("UMS_SUBCLASS_MEDIC", cast (GameSystems.subclassToInt GameSystems.Medic))
  , ("UMS_SUBCLASS_LOGISTICS", cast (GameSystems.subclassToInt GameSystems.Logistics))
  , ("UMS_CERT_NETWORK_EXPLOIT", cast (GameSystems.certToInt GameSystems.NetworkExploit))
  , ("UMS_CERT_CRYPTO_ANALYSIS", cast (GameSystems.certToInt GameSystems.CryptoAnalysis))
  , ("UMS_CERT_SOCIAL_ENG", cast (GameSystems.certToInt GameSystems.SocialEng))
  , ("UMS_CERT_FORENSIC_ANALYSIS", cast (GameSystems.certToInt GameSystems.ForensicAnalysis))
  , ("UMS_CERT_MALWARE_DESIGN", cast (GameSystems.certToInt GameSystems.MalwareDesign))
  , ("UMS_CERT_COUNTER_INTEL", cast (GameSystems.certToInt GameSystems.CounterIntel))
  , ("UMS_LOADOUT_WEAPON", cast (GameSystems.loadoutSlotToInt GameSystems.WeaponSlot))
  , ("UMS_LOADOUT_TOOL", cast (GameSystems.loadoutSlotToInt GameSystems.ToolSlot))
  , ("UMS_LOADOUT_CONSUMABLE", cast (GameSystems.loadoutSlotToInt GameSystems.ConsumableSlot))
  , ("UMS_ATTRIBUTE_STR", cast (GameSystems.attributeToInt GameSystems.STR))
  , ("UMS_ATTRIBUTE_DEX", cast (GameSystems.attributeToInt GameSystems.DEX))
  , ("UMS_ATTRIBUTE_INT", cast (GameSystems.attributeToInt GameSystems.INT))
  , ("UMS_ATTRIBUTE_CON", cast (GameSystems.attributeToInt GameSystems.CON))
  , ("UMS_ATTRIBUTE_WIL", cast (GameSystems.attributeToInt GameSystems.WIL))
  , ("UMS_ATTRIBUTE_CHA", cast (GameSystems.attributeToInt GameSystems.CHA))
  ]

private
renderConstant : (String, Nat) -> String
renderConstant (name, value) = "#define " ++ name ++ " " ++ show value ++ "u\n"

private
enumConstantDeclarations : String
enumConstantDeclarations = concat (map renderConstant enumConstants) ++ "\n"

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
      , ("UMS_MAX_PLAYERS", maxPlayers)
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
  , MkStruct "ums_player_info"
      [ field (constPtr CChar) "player_id", field (named "ums_coop_role") "role"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2", field CU8 "_pad3"
      , field CU8 "_pad4", field CU8 "_pad5", field CU8 "_pad6"
      , field CF64 "pos_x", field CF64 "pos_y" ]
  , MkStruct "ums_chat_message"
      [ field (constPtr CChar) "sender_id", field (constPtr CChar) "content"
      , field CF64 "timestamp" ]
  , MkStruct "ums_session_state"
      [ field (constPtr CChar) "session_id", field (named "ums_session_phase") "phase"
      , field (named "ums_multiplayer_alert") "alert"
      , field CU8 "_pad0", field CU8 "_pad1"
      , field (array maxPlayers (named "ums_player_info")) "players"
      , field CU32 "players_len" ]
  , MkStruct "ums_detection_event"
      [ field (named "ums_detection_source") "source"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field CU32 "severity", field CF64 "timestamp" ]
  , MkStruct "ums_player_state"
      [ field CU32 "hp", field CU32 "max_hp", field CU32 "armour"
      , field (named "ums_jessica_subclass") "subclass"
      , field CU8 "_pad0", field CU8 "_pad1", field CU8 "_pad2"
      , field (array 6 CU8) "attributes", field CU8 "_pad3", field CU8 "_pad4"
      , field CU32 "alert_score" ]
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
  , MkFunction CBool "idaptik_ums_add_item" [param levelPtr "level", param (constPtr (named "ums_world_item")) "item"]
  , MkFunction CBool "idaptik_ums_add_assassin" [param levelPtr "level", param (constPtr (named "ums_assassin_config")) "assassin"]
  , MkFunction CU32 "idaptik_ums_total_item_weight" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_count_items_by_kind" [param constLevelPtr "level", param CU8 "kind_tag"]
  , MkFunction (constPtr (named "ums_world_item")) "idaptik_ums_get_item" [param constLevelPtr "level", param CU32 "index"]
  , MkFunction CU8 "idaptik_ums_degrade_condition" [param levelPtr "level", param CU32 "item_index"]
  , MkFunction CU32 "idaptik_ums_total_enemy_count" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_threat_score" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_guards_in_zone" [param constLevelPtr "level", param (constPtr CChar) "zone_name"]
  , MkFunction CU32 "idaptik_ums_enemies_in_range" [param constLevelPtr "level", param CF64 "x_min", param CF64 "x_max"]
  , MkFunction CU8 "idaptik_ums_highest_guard_rank" [param constLevelPtr "level"]
  , MkFunction CBool "idaptik_ums_add_device_defence" [param levelPtr "level", param (constPtr (named "ums_device_defence_config")) "defence"]
  , MkFunction CBool "idaptik_ums_add_zone_transition" [param levelPtr "level", param (constPtr (named "ums_zone_transition")) "transition"]
  , MkFunction CBool "idaptik_ums_add_objective" [param levelPtr "level", param (constPtr (named "ums_mission_objective")) "objective"]
  , MkFunction CVoid "idaptik_ums_reset_objectives" []
  , MkFunction CU32 "idaptik_ums_required_objective_count" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_total_objective_count" [param constLevelPtr "level"]
  , MkFunction CBool "idaptik_ums_has_time_limit" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_get_time_limit" [param constLevelPtr "level"]
  , MkFunction (constPtr (named "ums_mission_objective")) "idaptik_ums_get_objective" [param constLevelPtr "level", param CU32 "index"]
  , MkFunction CBool "idaptik_ums_add_wiring" [param levelPtr "level", param (constPtr (named "ums_wiring_challenge")) "challenge"]
  , MkFunction CU32 "idaptik_ums_count_wiring_by_type" [param constLevelPtr "level", param CU8 "wiring_type"]
  , MkFunction CU32 "idaptik_ums_wiring_at_device" [param constLevelPtr "level", param (constPtr (named "ums_ip_address")) "ip"]
  , MkFunction CU32 "idaptik_ums_max_wiring_difficulty" [param constLevelPtr "level"]
  , MkFunction CU32 "idaptik_ums_avg_wiring_difficulty" [param constLevelPtr "level"]
  , MkFunction (constPtr (named "ums_wiring_challenge")) "idaptik_ums_get_wiring" [param constLevelPtr "level", param CU32 "index"]
  , MkFunction CU32 "idaptik_safe_add" [param CU32 "a", param CU32 "b", param CU32 "max_val"]
  , MkFunction CU32 "idaptik_safe_sub" [param CU32 "a", param CU32 "b"]
  , MkFunction CU32 "idaptik_safe_mul" [param CU32 "a", param CU32 "b", param CU32 "max_val"]
  , MkFunction CU32 "idaptik_safe_clamp" [param CU32 "value", param CU32 "min_val", param CU32 "max_val"]
  , MkFunction CU32 "idaptik_safe_percentage" [param CU32 "value", param CU32 "total"]
  , MkFunction CU32 "idaptik_safe_strlen" [param (constPtr CChar) "s", param CU32 "max_len"]
  , MkFunction CBool "idaptik_safe_is_printable_ascii" [param (constPtr CChar) "s"]
  , MkFunction CBool "idaptik_safe_token_compare" [param (constPtr CU8) "a", param (constPtr CU8) "b", param CU32 "len"]
  , MkFunction CU8 "idaptik_classify_keystroke" [param CU8 "keycode"]
  , MkFunction CBool "idaptik_mp_roles_disjoint" [param CU8 "role_a", param CU8 "role_b"]
  , MkFunction CBool "idaptik_mp_valid_role" [param CU8 "role"]
  , MkFunction CBool "idaptik_mp_alert_lte" [param CU8 "a", param CU8 "b"]
  , MkFunction CU8 "idaptik_mp_alert_max" [param CU8 "a", param CU8 "b"]
  , MkFunction CU8 "idaptik_mp_alert_escalate" [param CU8 "current"]
  , MkFunction CBool "idaptik_mp_add_player" [param (ptr (named "ums_session_state")) "session", param (constPtr (named "ums_player_info")) "player"]
  , MkFunction CU32 "idaptik_mp_count_role" [param (constPtr (named "ums_session_state")) "session", param CU8 "role"]
  , MkFunction CBool "idaptik_mp_can_start" [param (constPtr (named "ums_session_state")) "session"]
  , MkFunction CBool "idaptik_mp_valid_transition" [param CU8 "current", param CU8 "next"]
  , MkFunction CU32 "idaptik_gs_apply_damage" [param (ptr (named "ums_player_state")) "state", param CU32 "raw_damage", param CU8 "damage_type"]
  , MkFunction CU32 "idaptik_gs_heal" [param (ptr (named "ums_player_state")) "state", param CU32 "amount"]
  , MkFunction CBool "idaptik_gs_is_alive" [param (constPtr (named "ums_player_state")) "state"]
  , MkFunction CU8 "idaptik_gs_resolve_critical" [param CU8 "attribute_score", param CU8 "roll"]
  , MkFunction CU32 "idaptik_gs_add_detection" [param (ptr (named "ums_player_state")) "state", param (constPtr (named "ums_detection_event")) "event"]
  , MkFunction CU8 "idaptik_gs_alert_level_from_score" [param CU32 "score"]
  , MkFunction CU8 "idaptik_gs_skill_check" [param (constPtr (named "ums_player_state")) "state", param CU8 "attribute_idx", param CU8 "difficulty", param CU8 "roll"]
  , MkFunction CU8 "idaptik_gs_subclass_bonus" [param CU8 "subclass", param CU8 "context"]
  , MkFunction CBool "idaptik_gs_valid_loadout_slot" [param CU8 "slot"]
  , MkFunction CBool "idaptik_gs_valid_deck_capacity" [param CU8 "count"]
  , MkFunction (constPtr CChar) "ipc_load_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_save_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_validate_level_abi" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_list_levels" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_export_level_config" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_get_system_info" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_create_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_destroy_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_add_zone" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_add_device" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_add_guard" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_add_dog" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_add_drone" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_set_mission" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_set_physical" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_validate_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_serialize_level" [param (constPtr CChar) "payload"]
  , MkFunction (constPtr CChar) "ipc_deserialize_level" [param (constPtr CChar) "payload"]
  ]

public export
cHeader : String
cHeader =
  "/* SPDX-License-Identifier: AGPL-3.0-or-later */\n" ++
  "/* SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> */\n" ++
  "/* Generated by the typechecked Idris2 CABI module. DO NOT EDIT. */\n" ++
  "#ifndef IDAPTIK_UMS_H\n#define IDAPTIK_UMS_H\n\n" ++
  "#include <stdbool.h>\n#include <stddef.h>\n#include <stdint.h>\n\n" ++
  "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n" ++
  capacityDeclarations ++ aliasDeclarations ++ enumConstantDeclarations ++ concat (map renderStruct structs) ++
  concat (map renderFunction functions) ++
  "\n#ifdef __cplusplus\n}\n#endif\n\n#endif\n"

public export
levelCompatibilityHeader : String
levelCompatibilityHeader =
  "/* SPDX-License-Identifier: AGPL-3.0-or-later */\n" ++
  "/* SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk> */\n" ++
  "/* Generated compatibility include. New consumers should include idaptik_ums.h. */\n" ++
  "#ifndef IDAPTIK_UMS_LEVEL_H\n#define IDAPTIK_UMS_LEVEL_H\n\n" ++
  "#include \"idaptik_ums.h\"\n\n#endif\n"

public export
symbolList : String
symbolList = concat (map (\decl => functionName decl ++ "\n") functions)

usage : IO ()
usage = putStrLn "usage: idaptik-ums-abi-gen <c|level-compat|symbols>"

main : IO ()
main = do
  args <- getArgs
  case args of
    [_, "c"] => putStr cHeader
    [_, "level-compat"] => putStr levelCompatibilityHeader
    [_, "symbols"] => putStr symbolList
    _ => usage
