-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Refinement from semantic LevelData values to the abstract, bounded C ABI
||| value domain. This module proves preservation of accepted semantic values;
||| it does not claim that Idris2 has inspected a foreign compiler's layout.
module Representation

import Primitives
import Types
import Devices
import Zones
import Inventory
import Guards
import Dogs
import Drones
import Assassin
import Mission
import Wiring
import Physical
import Level

import Data.List
import Data.String
import Decidable.Equality

%default total

public export
maxDevices, maxZones, maxGuards, maxDogs, maxDrones : Nat
maxDevices = 256
maxZones = 64
maxGuards = 128
maxDogs = 64
maxDrones = 64

public export
maxAssassins, maxItems, maxWiring, maxZoneTransitions : Nat
maxAssassins = 16
maxItems = 512
maxWiring = 128
maxZoneTransitions = 64

public export
maxDeviceDefences, maxObjectives, maxPlayers : Nat
maxDeviceDefences = 256
maxObjectives = 32
maxPlayers = 8

public export
maxU32 : Integer
maxU32 = 4294967295

fitsU32 : Nat -> Bool
fitsU32 value = the Integer (cast value) <= maxU32

cStringSafe : String -> Bool
cStringSafe value = not ('\0' `elem` unpack value)

fitsMaybe : (a -> Bool) -> Maybe a -> Bool
fitsMaybe _ Nothing = True
fitsMaybe predicate (Just value) = predicate value

fitsItemKind : ItemKind -> Bool
fitsItemKind (Storage capacity) = fitsU32 capacity
fitsItemKind (Keycard zone) = cStringSafe zone
fitsItemKind _ = True

fitsItem : Item -> Bool
fitsItem item =
  cStringSafe item.id && cStringSafe item.name &&
  fitsItemKind item.kind && fitsU32 item.weight &&
  fitsMaybe fitsU32 item.usesRemaining

fitsWorldItem : WorldItem -> Bool
fitsWorldItem item = fitsItem item.item && cStringSafe item.container

fitsDevice : DeviceSpec -> Bool
fitsDevice device = cStringSafe device.name

fitsZone : Zone -> Bool
fitsZone zone = cStringSafe zone.name && fitsU32 zone.securityTier

fitsGuard : GuardPlacement -> Bool
fitsGuard guard = cStringSafe guard.zone

fitsAssassin : AssassinConfig -> Bool
fitsAssassin assassin =
  fitsU32 assassin.ambushCount && fitsU32 assassin.retreatThreshold

fitsWiring : WiringChallenge -> Bool
fitsWiring challenge = fitsU32 challenge.difficulty

fitsTransition : ZoneTransition -> Bool
fitsTransition transition =
  cStringSafe transition.fromZone && cStringSafe transition.toZone

fitsWhitelist : List String -> Bool
fitsWhitelist = all cStringSafe

fitsDefence : DeviceDefenceConfig -> Bool
fitsDefence defence =
  fitsMaybe fitsWhitelist defence.flags.instructionWhitelist &&
  fitsMaybe fitsU32 defence.flags.timeBomb &&
  fitsMaybe fitsU32 defence.flags.undoImmunity

fitsObjective : MissionObjective -> Bool
fitsObjective objective =
  cStringSafe objective.id && cStringSafe objective.description

fitsMission : MissionConfig -> Bool
fitsMission mission =
  cStringSafe mission.missionId && cStringSafe mission.locationId &&
  length mission.objectives <= maxObjectives &&
  all fitsObjective mission.objectives &&
  fitsMaybe fitsU32 mission.timeLimit

fitsPhysical : PhysicalConfig -> Bool
fitsPhysical physical = fitsU32 physical.numberOfCovertLinks

require : Bool -> String -> List String
require True _ = []
require False message = [message]

||| Every narrowing or sentinel obligation imposed by the current ums_level_data
||| representation. An empty result is the evidence required by `AbiLevel`.
public export
representationErrors : LevelData -> List String
representationErrors level =
     require (length level.devices <= maxDevices) "devices exceeds UMS_MAX_DEVICES"
  ++ require (length level.zones <= maxZones) "zones exceeds UMS_MAX_ZONES"
  ++ require (length level.guards <= maxGuards) "guards exceeds UMS_MAX_GUARDS"
  ++ require (length level.dogs <= maxDogs) "dogs exceeds UMS_MAX_DOGS"
  ++ require (length level.drones <= maxDrones) "drones exceeds UMS_MAX_DRONES"
  ++ require (length level.assassins <= maxAssassins) "assassins exceeds UMS_MAX_ASSASSINS"
  ++ require (length level.items <= maxItems) "items exceeds UMS_MAX_ITEMS"
  ++ require (length level.wiring <= maxWiring) "wiring exceeds UMS_MAX_WIRING"
  ++ require (length level.zoneTransitions <= maxZoneTransitions) "zone_transitions exceeds UMS_MAX_ZONE_TRANSITIONS"
  ++ require (length level.deviceDefences <= maxDeviceDefences) "device_defences exceeds UMS_MAX_DEVICE_DEFENCES"
  ++ require (all fitsDevice level.devices) "devices contains a non-C-string name"
  ++ require (all fitsZone level.zones) "zones contains an unrepresentable name or security_tier"
  ++ require (all fitsGuard level.guards) "guards contains a non-C-string zone"
  ++ require (all fitsAssassin level.assassins) "assassins contains a value wider than uint32_t"
  ++ require (all fitsWorldItem level.items) "items contains an unrepresentable string, optional, or uint32_t value"
  ++ require (all fitsWiring level.wiring) "wiring contains a difficulty wider than uint32_t"
  ++ require (all fitsTransition level.zoneTransitions) "zone_transitions contains a non-C-string zone"
  ++ require (all fitsDefence level.deviceDefences) "device_defences contains a noncanonical string or uint32_t value"
  ++ require (fitsMission level.mission) "mission contains too many objectives or an unrepresentable field"
  ++ require (fitsPhysical level.physical) "physical.covert_links is wider than uint32_t"

||| An abstract physical value is exactly a semantic value accompanied by
||| machine-checked evidence that all current C ABI narrowing obligations pass.
public export
record AbiLevel where
  constructor MkAbiLevel
  semantic : LevelData
  0 representable : representationErrors semantic = []

public export
forgetAbiLevel : AbiLevel -> LevelData
forgetAbiLevel physical = physical.semantic

||| Successful refinement carries the equality showing that no field was
||| truncated, defaulted, reordered, or otherwise changed.
public export
RefinedLevel : LevelData -> Type
RefinedLevel source = (physical : AbiLevel ** forgetAbiLevel physical = source)

public export
refineLevel : (source : LevelData) -> Either (List String) (RefinedLevel source)
refineLevel source =
  case decEq (representationErrors source) [] of
    Yes evidence => Right (MkAbiLevel source evidence ** Refl)
    No _ => Left (representationErrors source)

||| Explicit flag/payload representation used by optional C fields. The
||| encoder chooses the declared default for an inactive payload.
public export
record AbiOptional a where
  constructor MkAbiOptional
  hasValue : Bool
  payload : a

public export
encodeOptional : (inactiveDefault : a) -> Maybe a -> AbiOptional a
encodeOptional inactiveDefault Nothing = MkAbiOptional False inactiveDefault
encodeOptional _ (Just value) = MkAbiOptional True value

||| Decoding refuses a non-default inactive payload and returns evidence that
||| re-encoding the decoded value reproduces the physical representation.
public export
decodeOptional : DecEq a =>
                 (inactiveDefault : a) ->
                 (physical : AbiOptional a) ->
                 Either String (value : Maybe a ** encodeOptional inactiveDefault value = physical)
decodeOptional _ (MkAbiOptional True payload) = Right (Just payload ** Refl)
decodeOptional inactiveDefault (MkAbiOptional False payload) =
  case decEq payload inactiveDefault of
    Yes Refl => Right (Nothing ** Refl)
    No _ => Left "inactive optional payload is not canonical"

||| Flattened value model corresponding to ums_item_kind. Nat is used for the
||| fields so invalid or out-of-range physical inputs remain expressible and
||| can be refused by the decoder.
public export
record AbiItemKind where
  constructor MkAbiItemKind
  tag : Nat
  subType : Nat
  capacity : Nat
  zoneName : Maybe String

cableCode : CableType -> Nat
cableCode Ethernet = 0
cableCode FibreLC = 1
cableCode FibreSC = 2
cableCode Serial = 3
cableCode USB = 4
cableCode Universal = 5

adapterCode : AdapterType -> Nat
adapterCode EthernetToFibre = 0
adapterCode USBToSerial = 1
adapterCode MediaConverter = 2

toolCode : ToolType -> Nat
toolCode Crimper = 0
toolCode Splicer = 1
toolCode Multimeter = 2
toolCode WireCutter = 3
toolCode Debugger = 4

moduleCode : ModuleType -> Nat
moduleCode SFP = 0
moduleCode GBIC = 1
moduleCode QSFP = 2
moduleCode Transceiver = 3

consumableCode : ConsumableType -> Nat
consumableCode BatteryPack = 0
consumableCode EMP = 1
consumableCode SmokeGrenade = 2
consumableCode Decryptor = 3

public export
encodeItemKind : ItemKind -> AbiItemKind
encodeItemKind (Cable subtype) = MkAbiItemKind 0 (cableCode subtype) 0 Nothing
encodeItemKind (Adapter subtype) = MkAbiItemKind 1 (adapterCode subtype) 0 Nothing
encodeItemKind (Tool subtype) = MkAbiItemKind 2 (toolCode subtype) 0 Nothing
encodeItemKind (Module subtype) = MkAbiItemKind 3 (moduleCode subtype) 0 Nothing
encodeItemKind (Storage capacity) = MkAbiItemKind 4 0 capacity Nothing
encodeItemKind (Consumable subtype) = MkAbiItemKind 5 (consumableCode subtype) 0 Nothing
encodeItemKind (Keycard zone) = MkAbiItemKind 6 0 0 (Just zone)
encodeItemKind Radio = MkAbiItemKind 7 0 0 Nothing

||| Only canonical tag/payload combinations decode. The dependent result is
||| evidence that re-encoding returns the exact supplied physical value.
public export
decodeItemKind : (physical : AbiItemKind) ->
                 Either String (value : ItemKind ** encodeItemKind value = physical)
decodeItemKind (MkAbiItemKind 0 0 0 Nothing) = Right (Cable Ethernet ** Refl)
decodeItemKind (MkAbiItemKind 0 1 0 Nothing) = Right (Cable FibreLC ** Refl)
decodeItemKind (MkAbiItemKind 0 2 0 Nothing) = Right (Cable FibreSC ** Refl)
decodeItemKind (MkAbiItemKind 0 3 0 Nothing) = Right (Cable Serial ** Refl)
decodeItemKind (MkAbiItemKind 0 4 0 Nothing) = Right (Cable USB ** Refl)
decodeItemKind (MkAbiItemKind 0 5 0 Nothing) = Right (Cable Universal ** Refl)
decodeItemKind (MkAbiItemKind 1 0 0 Nothing) = Right (Adapter EthernetToFibre ** Refl)
decodeItemKind (MkAbiItemKind 1 1 0 Nothing) = Right (Adapter USBToSerial ** Refl)
decodeItemKind (MkAbiItemKind 1 2 0 Nothing) = Right (Adapter MediaConverter ** Refl)
decodeItemKind (MkAbiItemKind 2 0 0 Nothing) = Right (Tool Crimper ** Refl)
decodeItemKind (MkAbiItemKind 2 1 0 Nothing) = Right (Tool Splicer ** Refl)
decodeItemKind (MkAbiItemKind 2 2 0 Nothing) = Right (Tool Multimeter ** Refl)
decodeItemKind (MkAbiItemKind 2 3 0 Nothing) = Right (Tool WireCutter ** Refl)
decodeItemKind (MkAbiItemKind 2 4 0 Nothing) = Right (Tool Debugger ** Refl)
decodeItemKind (MkAbiItemKind 3 0 0 Nothing) = Right (Module SFP ** Refl)
decodeItemKind (MkAbiItemKind 3 1 0 Nothing) = Right (Module GBIC ** Refl)
decodeItemKind (MkAbiItemKind 3 2 0 Nothing) = Right (Module QSFP ** Refl)
decodeItemKind (MkAbiItemKind 3 3 0 Nothing) = Right (Module Transceiver ** Refl)
decodeItemKind (MkAbiItemKind 4 0 capacity Nothing) = Right (Storage capacity ** Refl)
decodeItemKind (MkAbiItemKind 5 0 0 Nothing) = Right (Consumable BatteryPack ** Refl)
decodeItemKind (MkAbiItemKind 5 1 0 Nothing) = Right (Consumable EMP ** Refl)
decodeItemKind (MkAbiItemKind 5 2 0 Nothing) = Right (Consumable SmokeGrenade ** Refl)
decodeItemKind (MkAbiItemKind 5 3 0 Nothing) = Right (Consumable Decryptor ** Refl)
decodeItemKind (MkAbiItemKind 6 0 0 (Just zone)) = Right (Keycard zone ** Refl)
decodeItemKind (MkAbiItemKind 7 0 0 Nothing) = Right (Radio ** Refl)
decodeItemKind _ = Left "item kind has a noncanonical tag/payload combination"

||| Machine-checked semantic-to-physical-to-semantic identity for every
||| ItemKind constructor and subtype.
public export
decodeEncodeItemKind : (value : ItemKind) ->
                       decodeItemKind (encodeItemKind value) = Right (value ** Refl)
decodeEncodeItemKind (Cable Ethernet) = Refl
decodeEncodeItemKind (Cable FibreLC) = Refl
decodeEncodeItemKind (Cable FibreSC) = Refl
decodeEncodeItemKind (Cable Serial) = Refl
decodeEncodeItemKind (Cable USB) = Refl
decodeEncodeItemKind (Cable Universal) = Refl
decodeEncodeItemKind (Adapter EthernetToFibre) = Refl
decodeEncodeItemKind (Adapter USBToSerial) = Refl
decodeEncodeItemKind (Adapter MediaConverter) = Refl
decodeEncodeItemKind (Tool Crimper) = Refl
decodeEncodeItemKind (Tool Splicer) = Refl
decodeEncodeItemKind (Tool Multimeter) = Refl
decodeEncodeItemKind (Tool WireCutter) = Refl
decodeEncodeItemKind (Tool Debugger) = Refl
decodeEncodeItemKind (Module SFP) = Refl
decodeEncodeItemKind (Module GBIC) = Refl
decodeEncodeItemKind (Module QSFP) = Refl
decodeEncodeItemKind (Module Transceiver) = Refl
decodeEncodeItemKind (Storage capacity) = Refl
decodeEncodeItemKind (Consumable BatteryPack) = Refl
decodeEncodeItemKind (Consumable EMP) = Refl
decodeEncodeItemKind (Consumable SmokeGrenade) = Refl
decodeEncodeItemKind (Consumable Decryptor) = Refl
decodeEncodeItemKind (Keycard zone) = Refl
decodeEncodeItemKind Radio = Refl
