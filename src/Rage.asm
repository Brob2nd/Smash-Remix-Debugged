// Rage.asm
if !{defined __RAGE__} {
define __RAGE__()
print "included Rage.asm\n"

scope Rage {
    attacker_damage_percent:
    db 0x0000
    OS.align(4)

    constant RAGE_OFF(0x0)
    constant RAGE_ULT(0x1)
    constant RAGE_FOUR(0x2)
    constant RAGE_MANIC(0x3)
    constant RAGE_DEPRESS(0x4)

    // 800E3EBC+b4=800E3F70
    // direct attack:
    // s1 = attacker struct -> 0x002C - Total Percent damage
    // save attacker %
    scope direct_attack: {
        OS.patch_start(0x5F770, 0x800E3F70)
        j       direct_attack
        nop
        _return:
        OS.patch_end()

        lw      a1, 0x7F0(s5) // original line 1
        lw      a2, 0xC(s0) // original line 2

        Toggles.read(entry_rage, t0)      // t0 = rage toggle
        beqz    t0, _end                  // branch if toggle is disabled
        nop

        // s1 = attacker struct
        lw      t0, 0x2C(s1) // t0 = attacker damage percent
        li      t1, attacker_damage_percent     // t1 = attacker_damage_percent address
        sw      t0, 0x0000(t1)                  // update attacker_damage_percent

        _end:
        j       _return
        nop
    }

    // 800E3EBC+240=800E40FC
    // projectile attack:
    // t6 = attacker struct -> 0x002C - Total Percent damage
    // save attacker %
    scope projectile_attack: {
        OS.patch_start(0x5F8FC, 0x800E40FC)
        j       projectile_attack
        nop
        _return:
        OS.patch_end()

        lw      t7, 0x30(s1) // original line 1
        lw      a0, 0x2c(s5) // original line 2

        Toggles.read(entry_rage, t0)      // t0 = rage toggle
        beqz    t0, _end                  // branch if toggle is disabled
        nop

        // s2 = item object
        lw      t0, 0xC(s2)
        lw      t0, 0x0084(t0)      // t0 = item special struct
        lw      t0, 0x0008(t0)      // t0 = owner object
        beqz    t0, _end            // skip if there's no owner object
        lli     t1, 0x03E8          // t1 = 0x03E8 (player type)
        lw      t2, 0x0000(t0)      // t2 = owner object type
        bne     t1, t2, _end        // skip if owner object is not a player object
        nop

        // if the item owner is a player
        lw      t0, 0x0084(t0) // t0 = attacker struct
        lw      t0, 0x2C(t0) // t0 = attacker damage percent
        li      t1, attacker_damage_percent     // t1 = attacker_damage_percent address
        sw      t0, 0x0000(t1)                  // update attacker_damage_percent

        _end:
        j       _return
        nop
    }

    // 8014AFD0+90=8014B060
    // throw
    // save attacker %
    scope throw: {
        OS.patch_start(0xC5AA0, 0x8014B060)
        j       throw
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_rage, t0)      // t0 = rage toggle
        beqz    t0, _end                  // branch if toggle is disabled
        nop

        // s0 = struct for the player applying the throw
        lw      t0, 0x2C(s0) // t0 = attacker damage percent
        li      t1, attacker_damage_percent     // t1 = attacker_damage_percent address
        sw      t0, 0x0000(t1)                  // update attacker_damage_percent

        _end:
        lw      a0, 0x002C(s1) // original line 1
        lw      t1, 0x000C(v1) // original line 2

        j       _return
        nop
    }

    // 800E9D78+1E8=800E9F60
    // sets final knockback value
    // (before checking knockback value limits and clamping them)
    scope knockback_multiply: {
        OS.patch_start(0x65760, 0x800E9F60)
        j       knockback_multiply
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_rage, t0)      // t0 = rage toggle
        beqz    t0, _end                  // branch if toggle is disabled
        nop

        // (Ultimate) Formula: 1 + [(ATTACKER_DAMAGE - 35)/115 * 0.1]
        // For other settings, we make a change to the (0.1) at the end
        // Starts at 35, caps at 150

        // For fixed knockback moves, a3 = 0
        // Skip if Ultimate
        fixed_kb_check_skip:
        // if not set to Ultimate, just continue
        ori     t1, r0, RAGE_ULT
        bne     t0, t1, _continue
        nop

        // if Ultimate, check if it's a fixed knockback move
        bnez    a3, _end
        nop

        _continue:
        // Load attacker damage percent
        li      t1, attacker_damage_percent     // t1 = attacker_damage_percent address
        lw      t0, 0x0000(t1)                  // t0 = attacker_damage_percent

        // Clamp damage used in calculation to [35, 150]
        ori         t2, r0, 0x22 // 34
        bgt         t0, t2, lower_clamp_after // skip if >= 35
        nop

        ori         t0, r0, 0x23 // 35

        lower_clamp_after:

        ori         t2, r0, 0x97 // 151
        blt         t0, t2, upper_clamp_after // skip if <= 150
        nop

        ori         t0, r0, 0x96 // 150

        upper_clamp_after:

        addiu       t0, t0, -0x23 // t0 = (damage - 35)

        mtc1        t0, f6  // f6 = (damage - 35) (int)
        cvt.s.w     f6, f6  // f6 = float((damage - 35))

        lui         t2, 0x42E6 // t2 = 115.0F
        mtc1        t2, f8  // f8 = 115.0F

        div.s       f10, f6, f8 // f10 = (ATTACKER_DAMAGE - 35)/115
        nop

        // Here we're loading the final multiplier (0.1 for Ultimate)
        // For other options, we change it to other values instead
        Toggles.read(entry_rage, t0)      // t0 = rage toggle

        // t2 = final multiplier (0.1 in the formula for Ultimate)

        set_final_multiplier:
        // Ultimate: 0.1
        ori         t3, r0, RAGE_ULT
        beq         t0, t3, set_final_multiplier_continue // if toggle matches, load multiplier and branch
        lui         t2, 0x3DCD // t2 = 0.100098F

        // Smash 4: 0.15
        ori         t3, r0, RAGE_FOUR
        beq         t0, t3, set_final_multiplier_continue // if toggle matches, load multiplier and branch
        lui         t2, 0x3E1A // t2 = 0.15039063F

        // Manic: 0.5
        ori         t3, r0, RAGE_MANIC
        beq         t0, t3, set_final_multiplier_continue // if toggle matches, load multiplier and branch
        lui         t2, 0x3F00 // t2 = 0.5F

        // Depression: -0.5
        ori         t3, r0, RAGE_DEPRESS
        beq         t0, t3, set_final_multiplier_continue // if toggle matches, load multiplier and branch
        lui         t2, 0xBF00 // t2 = -0.5F
    
        set_final_multiplier_continue:
        mtc1        t2, f8  // f8 = multiplier set in t2

        mul.s       f6, f10, f8 // f6 = [(ATTACKER_DAMAGE - 35)/115 (f10) * 0.1 (f8)]
        nop

        lui         t2, 0x3F80 // t2 = 1.0
        mtc1        t2, f8  // f8 = 1.0

        add.s       f6, f6, f8 // f6 = 1 + [multiplier]
        nop

        mul.s       f2, f2, f6 // f2 = original knockback * rage multiplier
        nop

        sw      r0, 0x0000(t1)                  // save attacker_damage_percent = 0

        _end:

        lui at, 0x8013 // original line 1
        lwc1 f0, 0xFF2C(at) // original line 2 - loads 2500.0F to clamp knockback speed

        j       _return
        nop
    }

    // 800E2048 + 388
    // Runs every frame
    // This patch makes players emit smoke particles to indicate Rage
    // Starts emiting smoke at 100, increases at 125, then again at 150
    scope gen_gfx: {
        OS.patch_start(0x5DBD0, 0x800E23D0)
        j       gen_gfx
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_rage, t0)      // t0 = rage toggle
        beqz    t0, _original             // branch if toggle is disabled
        nop

        lw      t0, 0x2C(s1)                // t0 = current damage percent

        // If damage < 100, skip
        ori         t2, r0, 0x64 // 100
        blt         t0, t2, _original
        nop

        ori         t3, r0, 0x003F  // % 64

        // If damage < 125, keep our divider and move on
        ori         t2, r0, 0x7D // 125
        blt         t0, t2, smoke_spawn
        nop

        ori         t3, r0, 0x001F  // % 32

        // If damage < 150, keep our divider and move on
        ori         t2, r0, 0x96 // 150
        blt         t0, t2, smoke_spawn
        nop

        ori         t3, r0, 0x000F  // % 16

        smoke_spawn:
        // Using t3 in the "and" working as a "mod" operation (division remainder)
        li      t5, Global.frame_counter // ~
        lw      t5, 0x0000(t5)           // t5 = global frame count

        and     t7, t5, t3
        bnez    t7, _original
        nop

        OS.save_registers()

        // ftParticle_MakeEffectKind(fighter_gobj, Ef_Kind_DustExpandLarge, 4, NULL, NULL, fp->lr, FALSE, FALSE);
        lw      a0, 0x0004(s1)              // a0 = player object
        lw      a1, 0x0084(a0)              // a1 = player struct
        addiu   sp,sp,-0x30
        sw      r0, 0x10(sp)
        lw      t2, 0x44(a1)
        lli     a1, 0x07                    // small, scattered, smoke GFX
        sw      r0, 0x1c(sp)
        sw      r0, 0x18(sp)
        or      a2, r0, r0
        or      a3, r0, r0
        jal     0x800EABDC
        sw      t2, 0x14(sp)
        addiu   sp,sp,0x30

        OS.restore_registers()

        _original:
        sh  r0, 0x00D0(s1) // original line 1
        sh  t9, 0x00CC(s1) // original line 2

        _end:
        j       _return
        nop
    }
}

} // __RAGE__