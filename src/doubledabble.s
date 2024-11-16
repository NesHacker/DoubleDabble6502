; Double Dabble 6502 Implementation
; By NesHacker

;-------------------------------------------------------------------------------
; Variables and Macros
;-------------------------------------------------------------------------------

; Holds major flags for the game. Bit 7 indicates to the NMI handler that state
; update are complete and the graphics can be updated. Bits 0-6 are unused.
game_flags = $20

; Holds the "rupees" value that are converted to BCD
rupees = $300

;-------------------------------------------------------------------------------
; Sets the game state's "render ready" flag. This tells the NMI handler that
; game updates are complete and that it can update the system's VRAM.
;-------------------------------------------------------------------------------
.macro SetRenderFlag
  lda #%10000000
  ora game_flags
  sta game_flags
.endmacro

;-------------------------------------------------------------------------------
; Unsets the game state's "render ready" flag. This tells the NMI handler that
; game updates are not complete, and that it should not update the system's
; VRAM.
;-------------------------------------------------------------------------------
.macro UnsetRenderFlag
  lda #%01111111
  and game_flags
  sta game_flags
.endmacro

;-------------------------------------------------------------------------------
; iNES Header, Vectors, and Startup Section
;-------------------------------------------------------------------------------
.segment "HEADER"
  .byte $4E, $45, $53, $1A  ; iNES header identifier
  .byte 2                   ; 2x 16KB PRG-ROM Banks
  .byte 1                   ; 1x  8KB CHR-ROM
  .byte $00                 ; mapper 0 (NROM)
  .byte $00                 ; System: NES

.segment "STARTUP"

.segment "VECTORS"
  .addr nmi, reset, 0

;-------------------------------------------------------------------------------
; Character (Pattern) Data for the game. This is an NROM game so it uses a fixed
; CHR-ROM. To edit the graphics, open the `src/bin/CHR-ROM.bin` file in YY-CHR.
; To get the file displaying correctly use the "2BPP NES" format.
;
; The first table contains the 8x16 sprites for the game, to make it easier to
; edit them use the "FC/NES x16" pattern option. The second table consists of
; mostly background tiles, so using the "Normal" pattern option is best.
;-------------------------------------------------------------------------------
.segment "CHARS"
.incbin "CHR-ROM.bin"

;-------------------------------------------------------------------------------
; Main Game Code
;-------------------------------------------------------------------------------
.segment "CODE"

; Library Includes
.include "ppu.s"
.include "joypad.s"

;-------------------------------------------------------------------------------
; Core double dabble algorithm that converts the rupees to BCD
;-------------------------------------------------------------------------------
.proc double_dabble
  ; 1) Set up the memory
  lda rupees
  sta $00
  lda #0
  sta $01 ; 100s place
  sta $02 ;  10s place
  sta $03 ;   1s place
  ; 2) Main Loop
  ldx #8
loop:
  ; 3) Inner-loop: check the digits
  ldy #3
digit_check_loop:
  lda $00, y
  cmp #5
  bcc next_digit
  clc
  adc #123
  sta $00, y
next_digit:
  dey
  bne digit_check_loop
  ; 4) Peform the shifts
  asl $00
  rol $03
  rol $02
  rol $01
  dex
  bne loop
  rts
.endproc

;-------------------------------------------------------------------------------
; Called in the render loop to print the decmial digits to the screen.
;-------------------------------------------------------------------------------
.proc print_bcd
  ; Set the VRAM address to $2043 (Row 2, Column 3 of Nametable A)
  lda #$20
  sta PPU_ADDR ; PPU_ADDRESS = $2006
  lda #$43
  sta PPU_ADDR
  ldx #1
  ; Print the digits using each BCD digit as an offset to the pattern table
print_loop:
  lda $00, x
  clc
  adc #$10
  sta PPU_DATA ; PPU_DATA = $2007
  inx
  cpx #4
  bne print_loop
  rts
.endproc

;-------------------------------------------------------------------------------
; Called in the game loop to update the rupees based on controller input:
; * DPAD Right - Add 1 rupee
; * DPAD Left - Subtract 1 rupee
; * DPAD Up - Add 10 rupees
; * DPAD Down - Subtract 10 rupees
;-------------------------------------------------------------------------------
.proc update_rupees
  ldx #3
check_button_loop:
  txa
  asl
  tay
  lda button_map, y
  and joypad1_pressed
  beq continue
  iny
  lda button_map, y
  clc
  adc rupees
  sta rupees
  rts
continue:
  dex
  bpl check_button_loop
  rts
button_map:
  .byte BUTTON_LEFT, %11111111  ;  -1 = 0b11111111 in 2s complement
  .byte BUTTON_RIGHT, 1
  .byte BUTTON_DOWN, %11110110  ; -10 = 0b11110110 in 2s complement
  .byte BUTTON_UP, 10
.endproc

;-------------------------------------------------------------------------------
; The main routine for the program. This sets up and handles the execution of
; the game loop and controls memory flags that indicate to the rendering loop
; if the game logic has finished processing.
;
; For the most part if you're emodifying or playing with the code, you shouldn't
; have to make edits here. Instead make changes to `init_game` and `game_loop`
; below...
;-------------------------------------------------------------------------------
.proc main
  jsr init_game
loop:
  jsr game_loop
  SetRenderFlag
@wait_for_render:
  bit game_flags
  bmi @wait_for_render
  jmp loop
.endproc

;-------------------------------------------------------------------------------
; Non-maskable Interrupt Handler. This interrupt is executed at the end of each
; PPU rendering frame during the Vertical Blanking Interval (VBLANK). This
; interval lasts rougly 2273 CPU cycles, and to avoid graphical glitches all
; drawing in the "rendering_loop" should be completed within that timeframe.
;
; For the most part if you're modifying or playing with the code, you shouldn't
; have to touch the nmi directly. To change how the game renders update the
; `render_loop` routine below...
;-------------------------------------------------------------------------------
.proc nmi
  bit game_flags
  bpl @return
  jsr render_loop
  UnsetRenderFlag
@return:
  rti
.endproc

;-------------------------------------------------------------------------------
; Main game loop logic that runs every tick
;-------------------------------------------------------------------------------
.proc game_loop
  jsr read_joypad1
  jsr update_rupees
  jsr double_dabble
  rts
.endproc

;-------------------------------------------------------------------------------
; Rendering loop logic that runs during the NMI
;-------------------------------------------------------------------------------
.proc render_loop
  ; Transfer Sprites via OAM
  lda #$00
  sta OAM_ADDR
  lda #$02
  sta OAM_DMA

  ; Print the BCD digits
  jsr print_bcd

  ; Reset the VRAM address
  VramReset
  rts
.endproc

;-------------------------------------------------------------------------------
; Initializes the game on reset before the main loop begins to run
;-------------------------------------------------------------------------------
.proc init_game
  ; Initialize the game state
  jsr init_palettes

  ; Initialize the rupees to something interesting
  lda #145
  sta rupees

  ; Enable rendering and NMI
  lda #%10001000
  sta PPU_CTRL
  lda #%00011110
  sta PPU_MASK
  rts
.endproc

;-------------------------------------------------------------------------------
; Initializes the pallettes for the foreground and background graphics.
;-------------------------------------------------------------------------------
.proc init_palettes
  bit PPU_STATUS
  lda #$3F
  sta PPU_ADDR
  lda #$00
  sta PPU_ADDR
  ldx #0
@loop:
  lda palettes, x
  sta PPU_DATA
  inx
  cpx #32
  bne @loop
  rts
palettes:
  ; Nametable palettes
  .byte $0F, $05, $15, $37
  .byte $0F, $07, $17, $37
  .byte $0F, $0A, $1A, $37
  .byte $0F, $01, $11, $37
  ; Sprite palettes
  .byte $0F, $14, $23, $37
  .byte $0F, $0B, $27, $30
  .byte $0F, $0F, $0F, $0F
  .byte $0F, $0F, $0F, $0F
.endproc

;-------------------------------------------------------------------------------
; Core reset method for the game, this is called on powerup and when the system
; is reset. It is responsible for getting the system into a consistent state
; so that game logic will have the same effect every time it is run anew.
;-------------------------------------------------------------------------------
.proc reset
  sei
  cld
  ldx #$ff
  txs
  ldx #0
  stx PPU_CTRL
  stx PPU_MASK
  stx $4010
  ldx #%01000000
  stx $4017
  bit PPU_STATUS
  VblankWait
  ldx #0
  lda #0
@ram_reset_loop:
  sta $000, x
  sta $100, x
  sta $200, x
  sta $300, x
  sta $400, x
  sta $500, x
  sta $600, x
  sta $700, x
  inx
  bne @ram_reset_loop
  lda #%11101111
@sprite_reset_loop:
  sta $200, x
  inx
  bne @sprite_reset_loop
  lda #$00
  sta OAM_ADDR
  lda #$02
  sta OAM_DMA
  VblankWait
  bit PPU_STATUS
  lda #$3F
  sta PPU_ADDR
  lda #$00
  sta PPU_ADDR
  lda #$0F
  ldx #$20
@resetPalettesLoop:
  sta PPU_DATA
  dex
  bne @resetPalettesLoop
  jmp main
.endproc
