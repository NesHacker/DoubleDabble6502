;-------------------------------------------------------------------------------
; joypad.s
; State and routines for reading joypads (controllers)
;-------------------------------------------------------------------------------

; Controller port addresses
JOYPAD1 = $4016
JOYPAD2 = $4017

; Button masks
BUTTON_A      = 1 << 7
BUTTON_B      = 1 << 6
BUTTON_SELECT = 1 << 5
BUTTON_START  = 1 << 4
BUTTON_UP     = 1 << 3
BUTTON_DOWN   = 1 << 2
BUTTON_LEFT   = 1 << 1
BUTTON_RIGHT  = 1 << 0

;-------------------------------------------------------------------------------
; [$21-$22] Controller State
;-------------------------------------------------------------------------------
; The state for the controller is stored across two bytes, each of which is a
; bitfield where each bit corresponds to a single button on the controller. This
; demo only uses the first controller.
;
; The bits in each variable are mapped as such:
;
; [AB-+^.<>]
;  ||||||||
;  |||||||+--------> Bit 0: D-PAD Right
;  ||||||+---------> Bit 1: D-PAD Left
;  |||||+----------> Bit 2: D-PAD Down
;  ||||+-----------> Bit 3: D-PAD Up
;  |||+------------> Bit 4: Start
;  ||+-------------> Bit 5: Select
;  |+--------------> Bit 6: B
;  +---------------> Bit 7: A
;
;-------------------------------------------------------------------------------

; $21 - Bitfield of buttons are currently being held
joypad1_down = $21

; $22 - Bitfield of buttons were pressed this frame
joypad1_pressed = $22

;-------------------------------------------------------------------------------
; Reads the buttons for the joypad connected to slot 1.
; Sets the buttons being held along with which buttons were pressed this frame
; to the corresponding bitfields (see above).
;-------------------------------------------------------------------------------
.proc read_joypad1
  lda joypad1_down
  tay
  lda #1
  sta JOYPAD1
  sta joypad1_down
  lsr
  sta JOYPAD1
@loop:
  lda JOYPAD1
  lsr
  rol joypad1_down
  bcc @loop
  tya
  eor joypad1_down
  and joypad1_down
  sta joypad1_pressed
  rts
.endproc