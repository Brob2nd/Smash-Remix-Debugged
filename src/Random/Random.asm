// Random.asm

// This file contains file inclusions, action edits, and assembly for Random.

scope Random {
    // Insert Moveset files


    // Modify Action Parameters             // Action                       // Animation                        // Moveset Data             // Flags
    Character.edit_action_parameters(RANDOM, Action.Entry,                   File.RANDOM_IDLE,                    -1,                         -1)
    Character.edit_action_parameters(RANDOM, 0x006,                          File.RANDOM_IDLE,                    -1,                         -1)
    Character.edit_action_parameters(RANDOM, Action.ReviveWait,              File.RANDOM_IDLE,                    -1,                         -1)
    Character.edit_action_parameters(RANDOM, Action.Idle,                    File.RANDOM_IDLE,                    0x800000000,                -1)
    Character.edit_action_parameters(RANDOM, Action.Teeter,                  File.RANDOM_IDLE,                    0x800000000,                -1)
    Character.edit_action_parameters(RANDOM, Action.TeeterStart,             File.RANDOM_IDLE,                    0x800000000,                -1)
    Character.edit_action_parameters(RANDOM, Action.EggLay,                  File.RANDOM_IDLE,                    -1,                         -1)
    Character.edit_action_parameters(RANDOM, Action.JumpF,                   -1,                                   0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.JumpB,                   -1,                                   0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.JumpAerialF,             -1,                                   0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.JumpAerialB,             -1,                                   0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Sleep,                   File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Stun,                    File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Walk1,                   File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Walk2,                   File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Walk3,                   File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Dash,                    File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Run,                     File.RANDOM_IDLE,                    0x80000000,                 -1)
    Character.edit_action_parameters(RANDOM, Action.Taunt,                   0,                                   0x80000000,                  0)

    // Modify Actions            // Action              // Staling ID    // Main ASM          // Interrupt/Other ASM          // Movement/Physics ASM         // Collision ASM

    // Modify Menu Action Parameters             // Action      // Animation                // Moveset Data             // Flags

    Character.edit_menu_action_parameters(RANDOM, 0x0,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x1,           File.RANDOM_SELECT,     0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x2,           File.RANDOM_SELECT,     0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x3,           File.RANDOM_SELECT,     0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x4,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x5,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0x9,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0xA,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0xD,           File.RANDOM_IDLE,       0x80000000,                   -1)
    Character.edit_menu_action_parameters(RANDOM, 0xE,           File.RANDOM_IDLE,       0x80000000,                   -1)

    // Set menu zoom size.
    Character.table_patch_start(menu_zoom, Character.id.RANDOM, 0x4)
    float32 0.84
    OS.patch_end()

    // Set default costumes
    Character.set_default_costumes(Character.id.RANDOM, 0, 0, 0, 0, 0, 0, 0)
    Teams.add_team_costume(YELLOW, RANDOM, 0x0)

    // Shield colors for costume matching
    Character.set_costume_shield_colors(RANDOM, WHITE, WHITE, WHITE, WHITE, WHITE, WHITE, NA, NA)

    // Set Remix 1P ending music
    Character.table_patch_start(remix_1p_end_bgm, Character.id.RANDOM, 0x2)
    dh {MIDI.id.CREDITS_BRAWL}
    OS.patch_end()

    // @ Description
    // Random's extra actions
    scope Action {
        //constant Jab3(0x0DC)
        //constant JabLoopStart(0x0DD)
        //constant JabLoop(0x0DE)
        //constant JabLoopEnd(0x0DF)
        //constant HeadStand(0x0E0)
        //constant AppearAir(0x0E1)
        //constant BlueFalcon1(0x0E2)
        //constant BlueFalcon2(0x0E3)
        //constant FalconPunch(0x0E4)
        //constant FalconPunchAir(0x0E5)
        //constant FalconKick(0x0E6)
        //constant FalconKickFromGroundAir(0x0E7)
        //constant LandingFalconKick(0x0E8)
        //constant FalconKickEnd(0x0E9)
        //constant CollisionFalconKick(0x0EA)
        //constant FalconDive(0x0EB)
        //constant FalconDiveCatch(0x0EC)
        //constant FalconDiveEnd1(0x0ED)
        //constant FalconDiveEnd2(0x0EE)

        // strings!
        // string_0x0E0:; String.insert("HeadStand")

        action_string_table:
        dw 0 //dw string_0x0DC
        dw 0 //dw string_0x0DD
        dw 0 //dw string_0x0DE
        dw 0 //dw string_0x0DF
        dw 0 // dw string_0x0E0
        dw 0 //dw string_0x0E1
        dw 0 //dw string_0x0E2
        dw 0 //dw string_0x0E3
        dw 0 //dw string_0x0E4
        dw 0 //dw string_0x0E5
        dw 0 //dw string_0x0E6
        dw 0 //dw string_0x0E7
        dw 0 //dw string_0x0E8
        dw 0 //dw string_0x0E9
        dw 0 //dw string_0x0EA
        dw 0 //dw string_0x0EB
        dw 0 //dw string_0x0EC
        dw 0 //dw string_0x0ED
        dw 0 //dw string_0x0EE
    }

    // Set action strings
    Character.table_patch_start(action_string, Character.id.RANDOM, 0x4)
    dw  Action.action_string_table
    OS.patch_end()

}
