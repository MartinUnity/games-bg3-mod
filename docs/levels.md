# BG3 level names (authoritative dump)

Extracted from Gustav.pak + GustavX.pak + Shared.pak `*/Levels/*` folder names
(see tools/README.md for the recipe; 512 levels, deduped). This is the ground
truth for the wild-patrol level gate (Wild.lua `WILD_LEVEL_PATTERNS` /
`WILD_SAFE_PATTERNS`) - there is no complete online listing of internal level
names; community wikis only cover a handful.

No `GOB_` or `UND_` level prefix exists: goblin camp = `WLD_GoblinCamp_D`,
underdark = `WLD_Underdark_*`. Theme gates must match those real names.

## Act 1 wilderness (the wild-patrol maps) - annotated

- `TUT_Avernus_C` — Tutorial nautiloid (TUT exempt).
- `WLD_BlockerDruidGrove_A` — SAFE HAVEN: grove gate area. Exempted.
- `WLD_CAMP_CineTriggers` — cinematic triggers only. Exempted.
- `WLD_CIN_DaisyIntroSkull_A`
- `WLD_CIN_Dreamscene_Daisy_A`
- `WLD_CIN_Dreamscene_Forest_A`
- `WLD_CIN_Dreamscene_Laezel_A`
- `WLD_CIN_NautiloidPodRoom_A`
- `WLD_CIN_PrivateCampRoom_A`
- `WLD_CIN_Raft_A`
- `WLD_CIN_UnderdarkSubs_TemplateWrap_A`
- `WLD_CIN_UnderdarkSubs_TemplateWrap_B`
- `WLD_CIN_UnderdarkSubs_TemplateWrap_C`
- `WLD_CIN_UnderdarkSubs_TemplateWrap_D`
- `WLD_CIN_UnderdarkSubs_TemplateWrap_E`
- `WLD_Campfire_E` — SAFE HAVEN: camp. Exempted.
- `WLD_Chapel_H` — Dank crypt / chapel.
- `WLD_Chapel_Push`
- `WLD_Crashsite_D` — Nautiloid crashsite area.
- `WLD_DaisyIntroIsland_A`
- `WLD_DenSubs_B` — Den interior (tiefling hideout region).
- `WLD_DruidSubs_B` — SAFE HAVEN: Druid Grove interior (Kagha, ritual, beach passage). Exempted via WILD_SAFE_PATTERNS.
- `WLD_Forest_G` — Forest area.
- `WLD_GoblinCamp_D` — Goblin Camp - goblin-warband theme applies.
- `WLD_HagLair_D` — Hag's lair.
- `WLD_Hag_C_Evil`
- `WLD_Hag_C_Happy`
- `WLD_Main_A` — Act 1 wilderness surface map (NAUTILOID crashsite -> grove entrance courtyard -> riverside -> blighted village edge). Main wild-patrol map.
- `WLD_NautiloidCockpit_A`
- `WLD_OwlbearCave_B` — Owlbear cave.
- `WLD_Plains_D` — Riverside plains.
- `WLD_Raft_A`
- `WLD_RangerCamp_I` — Ranger camp (another grove-adjacent safe area - watch logs).
- `WLD_SharTemple_E` — Shar temple (justiciars) - underdark theme applies.
- `WLD_UnderdarkShrine_A` — Underdark shrine - theme applies.
- `WLD_UnderdarkSubs_C` — Underdark sublevels - theme applies.
- `WLD_UnderdarkSubs_SharVista_A`
- `WLD_UnderdarkTransitions_A` — Underdark - theme applies.
- `WLD_UnderdarkTransitions_B` — Underdark - theme applies.
- `WLD_UnderdarkTransitions_C` — Underdark - theme applies.
- `WLD_Underdark_C` — Underdark - underdark theme applies.
- `WLD_VillageSubs_C` — Blighted village interiors.
- `WLD_Vista` — vista/camera level. Exempted.
- `WLD_ZhentarimBasement_B` — Zhentarim basement.

## All levels by prefix

### PLT_ (142)

- PLT_BGH_BaldursMouth_Walkway_A
- PLT_BGH_SteelWatchFoundry_CartElevator_A
- PLT_BGH_SteelwatchFoundry_Elevator_A
- PLT_BGH_SteelwatchFoundry_Elevator_B
- PLT_BGO_Battlefield_A
- PLT_BGO_CircusAftermath_A
- PLT_BGO_Circus_A
- PLT_BreweryElevator_A
- PLT_Bridge_Goblin
- PLT_CHA_OUTSIDE_FissureFloor_Unbroken
- PLT_CHA_Sarcophagus
- PLT_CINE_AstralPlane_ElfsongDream_A
- PLT_COL_ApostleStandArea
- PLT_COL_Elevator
- PLT_CRE_BloodOfLathander_Ring
- PLT_CRE_FloatingBed
- PLT_CRE_RailLift
- PLT_CRE_Roof_A
- PLT_CRE_Roof_A_Broken
- PLT_CRE_StainedGlass_A
- PLT_CRE_StainedGlass_A_Broken
- PLT_CRE_StainedGlass_B
- PLT_CRE_Tower_A
- PLT_CRE_Tower_A_Broken
- PLT_CRE_Tower_Lathander_A
- PLT_CRE_Tower_Lathander_A_Broken
- PLT_CTY_BlushingMermaidFixed_A
- PLT_CTY_BlushingMermaidHagstyle_A
- PLT_CTY_GazetteElevator_A
- PLT_CTY_JaheiraTreasure_A
- PLT_CTY_JaheiraTreasure_B
- PLT_CTY_JaheiraTreasure_C
- PLT_CTY_RamazithFurniture_A
- PLT_CTY_RamazithFurniture_B
- PLT_CTY_RamazithFurniture_C
- PLT_CTY_SteelTitanElevator_A
- PLT_CTY_SubmersibleGone_A
- PLT_CTY_Submersible_A
- PLT_Camp_WoodenStructure_4x8_Broken
- PLT_Camp_WoodenStructure_4x8_Intact
- PLT_Castle_Wall_Breakable_A_DestructHelp
- PLT_CazadorCageLift_A
- PLT_CazadorElevatorBottom_A
- PLT_CazadorElevator_A
- PLT_CazadorPayload_A
- PLT_DEN_Elevator
- PLT_END_DebugChainsPlatform
- PLT_END_MorphicPoolDestruction_A
- PLT_END_Nautiloid
- PLT_END_Platform_Netherbrain
- PLT_FOR_House_Floor
- PLT_FOR_House_Roof
- PLT_GEN_Barricade_I_Wood_A
- PLT_GEN_Bridge_LoosePlanks_B
- PLT_GEN_Statue_Guard_A
- PLT_GOB_HereticCage_Floor
- PLT_GOB_PriestDungeon_FlushPlatform
- PLT_GOB_PriestessGutPrison_Floor
- PLT_HAG_CageBottom
- PLT_HUM_Ruin_Platform_Broken_C
- PLT_HoH_HelmLift
- PLT_HoH_StatueSpinner
- PLT_IRN_Elevator
- PLT_LOW_GriefAltar
- PLT_LOW_Railcart
- PLT_LOW_VoloFate_ExecutionCart
- PLT_Log
- PLT_MF_MindArena_Platform_A
- PLT_MF_MindArena_Platform_A_2
- PLT_MF_MindArena_Platform_B
- PLT_MF_MindArena_Platform_C
- PLT_MF_MindArena_Platform_D
- PLT_MF_MindArena_Platform_E
- PLT_MF_MindArena_Platform_F
- PLT_MF_MindArena_Platform_G
- PLT_MF_MindArena_Platform_H
- PLT_MOO_Dungeon_RockPillar
- PLT_Moo_Chapel_A
- PLT_Moo_Chapel_Broken_A
- PLT_Moo_Tower_A
- PLT_Moo_Tower_Broken_A
- PLT_PLA_BanditCave_01
- PLT_PLA_BanditCave_02
- PLT_PLA_BanditCave_03
- PLT_PLA_BanditCave_04
- PLT_PLA_BanditCave_05
- PLT_PLA_GithChokepointBridge
- PLT_PLA_WeakenedFloor
- PLT_Platform_FloorWood_A_Old_4D_4W_B
- PLT_Platform_FloorWood_A_Old_4D_4W_D
- PLT_Platform_Goblin_01
- PLT_Platform_Goblin_02
- PLT_Platform_Goblin_03
- PLT_Platform_Goblin_04
- PLT_Platform_Goblin_05
- PLT_Platform_Goblin_06
- PLT_Platform_Goblin_07
- PLT_Platform_Goblin_08
- PLT_Platform_Goblin_10
- PLT_Platform_MonasteryBrewery_01
- PLT_Platform_MonasteryBrewery_02
- PLT_Platform_MonasteryBrewery_03
- PLT_Platform_Ruin_01
- PLT_SCL_Haven_GameplayLight_A
- PLT_SCL_HospitalLift
- PLT_SCL_MindFlayerColony_Elevator_B
- PLT_SCL_SHAR_Elevator_A
- PLT_SHA_Disc
- PLT_SHA_StaticDisc
- PLT_SewerRaft_01
- PLT_SingleCharacterInvisible
- PLT_SingleCharacterInvisible_Med
- PLT_SpiderWeb_12x4
- PLT_SpiderWeb_12x4_Medium
- PLT_SpiderWeb_12x4_Medium_B
- PLT_SpiderWeb_12x4_Small
- PLT_SpiderWeb_4x4
- PLT_SpiderWeb_8x4
- PLT_SteelWatchFoundry_Facade_Broken_A
- PLT_SteelWatchFoundry_Facade_Intact_A
- PLT_SteelWatchFoundry_Roof_Broken_A
- PLT_SteelWatchFoundry_Roof_Intact_A
- PLT_TUT_BreakableDeck
- PLT_TUT_Elevator
- PLT_TWN_Distillery_Elevator
- PLT_TWN_TollhouseDestructibleRoof
- PLT_Temple_Roof_Rubble_Breakable_A
- PLT_TollhouseDestructibleFloor
- PLT_UND_AdamantineForge
- PLT_UND_AdamantineForgeAnvil
- PLT_UND_FairyRings_MushroomPlatform_001
- PLT_UND_FairyRings_MushroomPlatform_002
- PLT_UND_HangingPlatform
- PLT_UND_HangingPlatform2
- PLT_UND_TemplePlatform
- PLT_Underdark_TeleportPlatform
- PLT_WLD_Tavern_Roof
- PLT_WYR_WyrmRockElevator
- PLT_WYR_WyrmRock_SouthBridge
- PLT_WYR_Wyrmway_BaldursHelmetAltar
- PLT_WellDepthsRock
- PLT_Zhent_Bridge_A

### CMP_ (48)

- CMP_Astarion
- CMP_BGO_Elfsong_A
- CMP_BGO_Elfsong_B
- CMP_BGO_Farm_A
- CMP_Basement_A
- CMP_BedElfsong_Unmade_A
- CMP_BedElfsong_Unmade_B
- CMP_Bed_Astarion_A
- CMP_Bed_Gale_A
- CMP_Bed_Halsin_A
- CMP_Bed_Jaheira_A
- CMP_Bed_Karlach_A
- CMP_Bed_Laezel
- CMP_Bed_Minsc_A
- CMP_Bed_Minthara_A
- CMP_Bed_Shadowheart_A
- CMP_Bed_Wyll_A
- CMP_CTY_Slums_A
- CMP_CaveGranite_A
- CMP_CaveSandstone_A
- CMP_CentralCampfire_Day
- CMP_CentralCampfire_Day_Bag1_A
- CMP_CentralCampfire_Day_Bag2_A
- CMP_CentralCampfire_Day_Bag3_A
- CMP_CentralCampfire_Day_Bag4_A
- CMP_DungeonAbbey_A
- CMP_DungeonGith_A
- CMP_DungeonShar_A
- CMP_Gale
- CMP_GithCrecheCave_A
- CMP_GlobaltimelineSceneTriggers_A
- CMP_Halsin_A
- CMP_HavenBeachSide_A
- CMP_Jaheira_A
- CMP_Karlach
- CMP_Laezel
- CMP_Mindflayer_B
- CMP_Minsc_A
- CMP_Minthara_A
- CMP_Moonrise_A
- CMP_Owlbear_test_A
- CMP_Shadowheart
- CMP_SharTemple_A
- CMP_SharessCaress_A
- CMP_Shrubbery_A
- CMP_Shrubbery_B
- CMP_Underdark_A
- CMP_Wyll

### WLD_ (43)

- WLD_BlockerDruidGrove_A
- WLD_CAMP_CineTriggers
- WLD_CIN_DaisyIntroSkull_A
- WLD_CIN_Dreamscene_Daisy_A
- WLD_CIN_Dreamscene_Forest_A
- WLD_CIN_Dreamscene_Laezel_A
- WLD_CIN_NautiloidPodRoom_A
- WLD_CIN_PrivateCampRoom_A
- WLD_CIN_Raft_A
- WLD_CIN_UnderdarkSubs_TemplateWrap_A
- WLD_CIN_UnderdarkSubs_TemplateWrap_B
- WLD_CIN_UnderdarkSubs_TemplateWrap_C
- WLD_CIN_UnderdarkSubs_TemplateWrap_D
- WLD_CIN_UnderdarkSubs_TemplateWrap_E
- WLD_Campfire_E
- WLD_Chapel_H
- WLD_Chapel_Push
- WLD_Crashsite_D
- WLD_DaisyIntroIsland_A
- WLD_DenSubs_B
- WLD_DruidSubs_B
- WLD_Forest_G
- WLD_GoblinCamp_D
- WLD_HagLair_D
- WLD_Hag_C_Evil
- WLD_Hag_C_Happy
- WLD_Main_A
- WLD_NautiloidCockpit_A
- WLD_OwlbearCave_B
- WLD_Plains_D
- WLD_Raft_A
- WLD_RangerCamp_I
- WLD_SharTemple_E
- WLD_UnderdarkShrine_A
- WLD_UnderdarkSubs_C
- WLD_UnderdarkSubs_SharVista_A
- WLD_UnderdarkTransitions_A
- WLD_UnderdarkTransitions_B
- WLD_UnderdarkTransitions_C
- WLD_Underdark_C
- WLD_VillageSubs_C
- WLD_Vista
- WLD_ZhentarimBasement_B

### CTY_ (40)

- CTY_AncientLair_A
- CTY_CIN_AstarionRomanceGraveyard_A
- CTY_CIN_BooRoom_A
- CTY_CIN_DaisyRomance_A
- CTY_CIN_HalsinRomance_A
- CTY_CIN_KarlachRomanceTavern_A
- CTY_CIN_PrivateCampRoom_A
- CTY_CIN_PrivateCampRoom_Elfsong_A
- CTY_CIN_PrivateCampRoom_Slums_A
- CTY_CIN_SeluniteCourtyard_A
- CTY_Catacombs_A
- CTY_CazSideRooms_A
- CTY_CazadorPalace_A
- CTY_DevilandSmithBasement
- CTY_DjinniLamp_A
- CTY_DockWarehouseBasement_A
- CTY_Figaro_Basement_A
- CTY_FireWorks_Basement_A
- CTY_GardenerStoreRoom_A
- CTY_GeneralStore_Basement_A
- CTY_Golbraith_Basement_A
- CTY_Groundkeeper_Basement_A
- CTY_Guildhall_Basement_A
- CTY_HagSurvivor_Basement_A
- CTY_LodgeBasement_A
- CTY_LowerCity_A
- CTY_LowerCity_Trailer_B
- CTY_Main_A
- CTY_MurderTribunal_A
- CTY_MusicStore_Basement_A
- CTY_Peartree_Basement_A
- CTY_PhilgraveBasement_A
- CTY_Rainforest_Basement_A
- CTY_SmugglerBasement_A
- CTY_SorcerousSundriesBasement_A
- CTY_Submersible_A
- CTY_Tabernacle_Basement_A
- CTY_Thumbo_Basement_A
- CTY_WQH_Basement_A
- CTY_WeddingChapel_A

### BGO_ (37)

- BGO_BlacksmithCellar_A
- BGO_BloodMerchantLab_A_ART
- BGO_CIN_PrivateCampRoom_A
- BGO_CIN_Ruins_A
- BGO_CIN_WyrmswayArena_Pickup_A
- BGO_DiabolistCellar_A_ART
- BGO_ElfsongBasement_A
- BGO_HagSupportHouse_A
- BGO_Heapside_Prison_A_Art
- BGO_HouseOfHopePuzzles_A
- BGO_HouseOfHope_C
- BGO_HouseOfHope_TemplateWrap_A
- BGO_HouseOfHope_TemplateWrap_B
- BGO_HouseOfHope_TemplateWrap_C
- BGO_HouseOfHope_TemplateWrap_D
- BGO_HouseOfHope_TemplateWrap_E
- BGO_JaheiraBasement_B
- BGO_JungleOfChult_A
- BGO_Main_A
- BGO_MerchantHouseBasement_A
- BGO_MorphicPool_A
- BGO_RamazithTower_A_ART
- BGO_Sharran_Grotto
- BGO_SmugglerTunnel_A
- BGO_SmugglersCave_Basement_A
- BGO_SteelWatchLabControlCenter_B
- BGO_UC_CazadorChapel_A
- BGO_UC_GuildHall_A
- BGO_UC_Ruins_B
- BGO_UC_Sewer_D_Backup
- BGO_WellDepths_A
- BGO_WindmillCellar_A
- BGO_WyrmRockDungeon_D_Art
- BGO_WyrmsCrossing_C
- BGO_WyrmsCrossing_Vista
- BGO_WyrmswayArena_Crystal_Art
- BGO_Wyrmsway_C

### CLT_ (33)

- CLT_ACT3_Astarion_A
- CLT_ACT3_Gale_A
- CLT_ACT3_Halsin_A
- CLT_ACT3_Jaheira_A
- CLT_ACT3_Karlach_A
- CLT_ACT3_Laezel
- CLT_ACT3_Minsc_A
- CLT_ACT3_Minthara_A
- CLT_ACT3_Shadowheart
- CLT_ACT3_Wyll_A
- CLT_BlackBox_A
- CLT_CMP_AstarionTriggers_A
- CLT_CMP_GaleTriggers_A
- CLT_CMP_HalsinTriggers_A
- CLT_CMP_JaheiraTriggers_A
- CLT_CMP_KarlachTriggers_A
- CLT_CMP_LaezelTriggers_A
- CLT_CMP_MintharaTriggers_A
- CLT_CMP_MintharaTriggers_B
- CLT_CMP_ShadowheartTriggers_A
- CLT_CMP_WyllTriggers_A
- CLT_DaisyDream01_A
- CLT_DaisyMissionStatement_A
- CLT_MagicMirror_A
- CLT_MimicEncounter_A
- CLT_Mizora_A
- CLT_MizorasPact_A
- CLT_OwlbearCub
- CLT_PrivateCampRoom_A
- CLT_VlaakithVisit_B
- CLT_VoloOperation_A
- CLT_WyllDance_A
- CLT_ZevlorsAppeal_A

### SYS_ (31)

- SYS_CC_AstralPlane_C
- SYS_CC_Astralplane_A
- SYS_CC_Astralplane_B
- SYS_CC_I
- SYS_CC_I_Timeline
- SYS_Character_Creation_A
- SYS_EQGeneration_NonEQ_A
- SYS_Hirelings
- SYS_IconGeneration_A
- SYS_IconLighting_Setup_Heads_01
- SYS_Menuscreen_Act1_A
- SYS_Menuscreen_Act3_A
- SYS_Menuscreen_Act3_B
- SYS_Menuscreen_Camp_A
- SYS_Menuscreen_Vista_A
- SYS_PortraitGeneration_A
- SYS_PortraitLighting_Setup_01
- SYS_PortraitLighting_Setup_02
- SYS_PortraitLighting_Setup_03
- SYS_PortraitLighting_Setup_04
- SYS_PortraitLighting_Setup_05
- SYS_PortraitLighting_Setup_06
- SYS_PortraitLighting_Setup_07
- SYS_PortraitLighting_Setup_08
- SYS_PortraitLighting_Setup_09
- SYS_PortraitLighting_Setup_10
- SYS_PortraitLighting_Setup_11
- SYS_PortraitLighting_Setup_12
- SYS_PortraitLighting_Setup_13
- SYS_PortraitPlayerRace_A
- SYS_Virtual_SoundStage_A

### BGH_ (26)

- BGH_ArtistHouse_A
- BGH_ArtistHouse_A_Haunted
- BGH_BaldursMouthGazette_A
- BGH_BaldursMouth_Basement_A
- BGH_Barracks_A_Art
- BGH_BlushingMermaidCellarB
- BGH_BlushingMermaid_A
- BGH_BonecloaksApothecary_A
- BGH_BonecloaksApothecary_Basement_A
- BGH_CountingHouseVaultConnection_A
- BGH_CountingHouseVault_B
- BGH_CountingHouseVault_C
- BGH_Countinghouse_C
- BGH_DiabolistHouse_A_ART
- BGH_ElfSongTavern_A_Art
- BGH_ElfsongTavern_PrivateRoom_Bloodied
- BGH_ElfsongTavern_PrivateRoom_Clean
- BGH_FigaroCosmeticShop_A
- BGH_Highberrys_cellar_A
- BGH_House_of_Grief
- BGH_PhilgraveMansion_A
- BGH_SerialKiller_A_ART
- BGH_SorcerersSundries_A_ART
- BGH_SteelWatchFoundry_B
- BGH_StormshoreTabernacle_A
- BGH_WaterQueenHouse_B_ART

### END_ (24)

- END_AstarionCave_A
- END_BaldursGate_Vista_A
- END_Beach_A
- END_CIN_BaldursGate_Vista_A
- END_CIN_ElfsongCamp_A
- END_CIN_GameFinale_TheHerosRevelry
- END_CIN_GameFinale_TheHerosRevelry_B
- END_CIN_KarlachAvernusFinale_A
- END_CIN_RaphaelPunished
- END_CIN_RuleMarket_A
- END_CIN_Sewers_A
- END_CIN_Streets_A
- END_CIN_Throneroom_D
- END_Cin_JergalChapel_A
- END_Cin_NetherBrainArenas_E
- END_FateOfCompanions_A
- END_HighHallRoofs_A
- END_HighHallSewers_A
- END_HighHall_C
- END_KarlachDock_A
- END_Main
- END_NetherBrainArenas_E
- END_NetherBrainArenas_Sky_A
- END_Ramaziths_Tower_A

### SCL_ (22)

- SCL_ArmyCampEmpty_A
- SCL_ArmyCamp_A
- SCL_CIN_GaleLastNight_A
- SCL_CIN_PrivateCampRoom_B
- SCL_CIN_PrivateCampRoom_Haven
- SCL_CIN_PrivateCampRoom_Main_A
- SCL_CIN_PrivateCampRoom_Moonrise_A
- SCL_CIN_PrivateCampRoom_Shar_A
- SCL_CIN_UncursedTown_A
- SCL_Campfire_A
- SCL_Foundation_A
- SCL_HavenBasementLights
- SCL_Intermezzo_C_ART
- SCL_KethericEntrance_A
- SCL_Main_A
- SCL_Mausoleum_E
- SCL_MindflayerColony_G
- SCL_MindflayerColony_Nautiloids
- SCL_MoonriseDungeon_E_ART
- SCL_Nightsong_A
- SCL_RuinsBattlefield_G
- SCL_VillageSubs_E

### GLO_ (17)

- GLO_CIN_GaleRomance_A
- GLO_CIN_Shadowfell_A
- GLO_CIN_ShadowheartWolfDream_A
- GLO_CIN_WyllTreeProposal_A
- GLO_Cambion_B
- GLO_Cambion_C
- GLO_SpellVocalComponent
- GLO_TUT_Avernus_TemplateWrap_A
- GLO_TUT_Avernus_TemplateWrap_B
- GLO_TUT_Avernus_TemplateWrap_C
- GLO_TUT_Avernus_TemplateWrap_D
- GLO_TUT_Avernus_TemplateWrap_E
- GLO_WLD_UnderdarkSubs_TemplateWrap_A
- GLO_WLD_UnderdarkSubs_TemplateWrap_B
- GLO_WLD_UnderdarkSubs_TemplateWrap_C
- GLO_WLD_UnderdarkSubs_TemplateWrap_D
- GLO_WLD_UnderdarkSubs_TemplateWrap_E

### LT_ (15)

- LT_CMP_ACT3_CentralBeds_A
- LT_CMP_BGO_Elfsong_Day
- LT_CMP_BGO_Elfsong_Night
- LT_CMP_CentralCampfire_B
- LT_CMP_Underdark_Day
- LT_CMP_Underdark_Night
- LT_CTY_AlcoholTradersCart
- LT_CTY_Lodge_Floor
- LT_CTY_Lodge_Floor_Broken
- LT_CTY_WineFestival
- LT_CoronationRoom_Massacre_A
- LT_LOW_BaldursMouth_MoveableWalkway
- LT_PLT_CHA_CageBottom
- LT_SYS_CC_AstralPlane_B
- LT_SorcerousSundriesBasement_Room_A

### INT_ (8)

- INT_AstralBridge_A
- INT_CIN_CityWalls_A
- INT_CIN_GortashOffice_A
- INT_CIN_MoonriseDungeon
- INT_CIN_Office_A
- INT_CIN_Streets_A
- INT_CIN_UncursedMoonrise_A
- INT_Main_A

### CRE_ (6)

- CRE_AstralPlane_E_Art
- CRE_CIN_PrivateCampRoom_A
- CRE_CIN_PrivateCampRoom_Cave_A
- CRE_CIN_PrivateCampRoom_Dungeon_A
- CRE_GithDungeon_A
- CRE_Main_A

### EPI_ (6)

- EPI_CIN_GaleHeaven_A
- EPI_CIN_Jail_A
- EPI_CIN_VlaakithThroneRoom_A
- EPI_CIN_VlaakithThroneRoom_B
- EPI_Campfire_A
- EPI_Main_A

### IRN_ (4)

- IRN_CIN_HostageCell_A
- IRN_IronThrone_C
- IRN_Main_A
- IRN_Submersible_A

### Basic_ (1)

- Basic_Level_A

### BGC_ (1)

- BGC_Stormshore_A

### CAMP_ (1)

- CAMP_Shadowheart_SDROM

### CIN_ (1)

- CIN_BaldursGate_Vista_A

### Cre_ (1)

- Cre_GithCreche_D

### GUS_ (1)

- GUS_WorkAtmosphere_A

### TestLevel_ (1)

- TestLevel_Tom

### TL_ (1)

- TL_MM_Prototype_Environment

### TUT_ (1)

- TUT_Avernus_C

### VoiceOfTheAbsolute_ (1)

- VoiceOfTheAbsolute

