// OnHit.asm
if !{defined __ON_HIT__} {
define __ON_HIT__()
print "included OnHit.asm\n"

scope OnHit {
    // @ Description
    // Patch that can be used to run functions when characters are hit.
    // Add entries to Character.on_hit
    // ftCommon_ProcDamageStopVoice (800E823C + 8)
    scope on_hit: {
        OS.patch_start(0x63A44, 0x800E8244)
        j       on_hit
        nop
        _return:
        OS.patch_end()

        sw      a0, 0x0020(sp)  // store a0 (original line 1)
        lw      a0, 0x0084(a0)  // a0 = player struct (original line 2)

        lw      t6, 0x0008(a0)  // t6 = character id

        sll     t6, t6, 2
        li      at, Character.on_hit.table
        addu    t6, t6, at              // t6 = entry
        lw      at, 0x0000(t6)          // at = characters entry in jump table
        beqz    at, _end                // skip if no entry
        nop
        jalr    at                      // jump to entry if exists
        nop

        _end:
        j       _return                     // return
        nop
    }
}

} // __ON_HIT__
