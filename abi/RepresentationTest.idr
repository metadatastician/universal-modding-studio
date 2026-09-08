-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025-2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Executable controls for Representation. Compile-time equalities live in
||| Representation itself; these checks demonstrate refusal paths compute.
module RepresentationTest

import Representation
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

import Data.Fin
import Data.List
import Data.String
import Decidable.Equality
import System

%default total

zeroIp : IpAddress
zeroIp = MkIpAddress 0 0 0 0

zeroX : WorldX
zeroX = MkWorldX 0.0

emptyMission : MissionConfig
emptyMission = MkMissionConfig "mission" "location" [] Nothing

emptyPhysical : PhysicalConfig
emptyPhysical = MkPhysicalConfig 0.0 100.0 2.0 False False 0

emptyLevel : LevelData
emptyLevel = MkLevelData
  [] [] [] [] [] [] [] [] emptyMission emptyPhysical [] [] False zeroIp zeroX

device : DeviceSpec
device = MkDeviceSpec Server zeroIp "server" Strong

withDevices : List DeviceSpec -> LevelData
withDevices devices = MkLevelData
  devices [] [] [] [] [] [] [] emptyMission emptyPhysical [] [] False zeroIp zeroX

withZones : List Zone -> LevelData
withZones zones = MkLevelData
  [] zones [] [] [] [] [] [] emptyMission emptyPhysical [] [] False zeroIp zeroX

withItems : List WorldItem -> LevelData
withItems items = MkLevelData
  [] [] [] [] [] [] items [] emptyMission emptyPhysical [] [] False zeroIp zeroX

withMission : MissionConfig -> LevelData
withMission mission = MkLevelData
  [] [] [] [] [] [] [] [] mission emptyPhysical [] [] False zeroIp zeroX

tooWide : Nat
tooWide = cast (the Integer 4294967296)

failsMentioning : LevelData -> String -> Bool
failsMentioning level needle =
  case refineLevel level of
    Left errors => any (needle `isInfixOf`) errors
    Right _ => False

refinesWithoutChange : LevelData -> Bool
refinesWithoutChange level =
  case refineLevel level of
    Left _ => False
    Right (_ ** Refl) => True

canonicalOptional : DecEq a => a -> AbiOptional a -> Bool
canonicalOptional inactiveDefault physical =
  case decodeOptional inactiveDefault physical of
    Left _ => False
    Right (_ ** Refl) => True

canonicalItemKind : AbiItemKind -> Bool
canonicalItemKind physical =
  case decodeItemKind physical of
    Left _ => False
    Right (_ ** Refl) => True

allItemKinds : List ItemKind
allItemKinds =
  [ Cable Ethernet, Cable Universal
  , Adapter MediaConverter
  , Tool Debugger
  , Module QSFP
  , Storage 4096
  , Consumable EMP
  , Keycard "secure"
  , Radio
  ]

itemRoundTrips : Bool
itemRoundTrips = all (canonicalItemKind . encodeItemKind) allItemKinds

checks : List (String, Bool)
checks =
  [ ("empty semantic level refines without change", refinesWithoutChange emptyLevel)
  , ("exact device capacity is admitted",
      refinesWithoutChange (withDevices (replicate maxDevices device)))
  , ("device capacity plus one is refused",
      failsMentioning (withDevices (replicate (S maxDevices) device)) "devices exceeds")
  , ("uint32 maximum is admitted",
      refinesWithoutChange (withZones [MkZone "max" (cast maxU32)]))
  , ("uint32 maximum plus one is refused",
      failsMentioning (withZones [MkZone "wide" tooWide]) "security_tier")
  , ("embedded NUL is refused at a C-string boundary",
      failsMentioning (withZones [MkZone (pack ['b', 'a', 'd', '\0', 'x']) 1]) "security_tier")
  , ("storage capacity narrowing is checked",
      let item = MkItem "disk" (Storage tooWide) "disk" 1 Good Nothing
          world = MkWorldItem item zeroX "server"
      in failsMentioning (withItems [world]) "items contains")
  , ("mission objective capacity is checked",
      let objective = MkMissionObjective "id" "description" True
          mission = MkMissionConfig "mission" "location" (replicate (S maxObjectives) objective) Nothing
      in failsMentioning (withMission mission) "mission contains")
  , ("inactive optional payload uses its canonical default",
      canonicalOptional (the Nat 0) (encodeOptional 0 Nothing))
  , ("active optional payload round-trips",
      canonicalOptional (the Nat 0) (encodeOptional 0 (Just 7)))
  , ("non-default inactive optional payload is refused",
      not (canonicalOptional (the Nat 0) (MkAbiOptional False 7)))
  , ("inactive optional IP uses the all-zero canonical payload",
      canonicalOptional zeroIp (encodeOptional zeroIp Nothing))
  , ("nonzero inactive optional IP payload is refused",
      not (canonicalOptional zeroIp
        (MkAbiOptional False (MkIpAddress 10 0 0 1))))
  , ("semantic item-kind variants round-trip", itemRoundTrips)
  , ("noncanonical inactive item-kind capacity is refused",
      not (canonicalItemKind (MkAbiItemKind 0 0 99 Nothing)))
  , ("invalid item-kind subtype is refused",
      not (canonicalItemKind (MkAbiItemKind 1 9 0 Nothing)))
  , ("keycard without its active zone payload is refused",
      not (canonicalItemKind (MkAbiItemKind 6 0 0 Nothing)))
  ]

report : (String, Bool) -> IO Bool
report (label, ok) = do
  putStrLn ((if ok then "  ok   " else "  FAIL ") ++ label)
  pure ok

covering
main : IO ()
main = do
  putStrLn "representation refinement checks:"
  results <- traverse report checks
  let passed = length (filter Prelude.id results)
  putStrLn (show passed ++ "/" ++ show (length results) ++ " checks passed")
  if passed == length results
    then putStrLn "PASS"
    else exitWith (ExitFailure 1)
