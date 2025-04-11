;Pong Client (c) 2025 by Rozsoft
;Creation Date:30.03.2025

  * = $0801
  
  !basic
  
  jmp Start
  
  !src "wic64.h"
  !src "wic64.asm"
  !src "macros.asm"
  
  
InitWIC64:

    +print check_info
    +wic64_detect
    +jcs device_not_present
    +jne legacy_firmware_detected

    +wic64_dont_disable_irqs
    +wic64_execute set_transfer_timeout, $05
    +wic64_execute set_remote_timeout, $05
    clc
    rts
    
Connect:

    +wic64_execute open_request, response, $05
    +jcs timeout
    +jne error

    +wic64_set_store_instruction jsr_store_action
    +print connect_info
    clc
    rts
 
Close:
    
    +wic64_reset_store_instruction    
    +wic64_execute close_request, $05
    rts

error:
    +wic64_reset_store_instruction
    +wic64_execute error_request, response, $05
    +jcs timeout
    +print response
    sec ;Failed
    rts
        
timeout:
    +print timeout_error
    sec
    rts
      
device_not_present:
    +newline
    +print device_not_present_error
    sec
    rts
    
legacy_firmware_detected:
    +newline
    +print legacy_firmware_error
    +paragraph
    +print legacy_firmware_hint
    sec
    rts

    
Write:
    
    +wic64_execute write_request, $05
    +jcs write_timeout
    +jne error
    lda #ACTION_REPEAT_NUMBER
    sta timeout_repeat
    clc
    rts

write_timeout:
    dec timeout_repeat
    bne Write
    jmp timeout
    
Read:

    lda #0
    sta bufptr
    sta buffer
    
    +wic64_execute read_request, $05
    +jcs read_timeout
    +jne error
    lda #ACTION_REPEAT_NUMBER
    sta timeout_repeat
    clc
    rts

read_timeout:
    dec timeout_repeat
    bne Read
    jmp timeout
    
jsr_store_action:
    jsr store_action
    
store_action:
    stx xbuf
    ldx bufptr
    sta buffer,x
    inx
    stx bufptr
    ldx xbuf
    rts
    
xbuf:                     !byte 0
bufptr:                   !byte 0
buffer:                   !fill BUFFER_SIZE, 0

error_request:            !byte "R", WIC64_GET_STATUS_MESSAGE, $01, $00, $00

open_request:             !byte "R", WIC64_TCP_OPEN
open_size:                !byte 0, 0
url:                      !text "000.000.000.000:6510x" ;Max IP length
url_size = * - url

write_request:            !byte "R", WIC64_TCP_WRITE
write_size                !byte 0,0 
payload:                  !fill BUFFER_SIZE, 0

read_request:             !byte "R", WIC64_TCP_READ, $00, $00
close_request             !byte "R", WIC64_TCP_CLOSE, $00, $00

set_transfer_timeout:     !byte "R", WIC64_SET_TRANSFER_TIMEOUT, $01, $00, $05
set_remote_timeout:       !byte "R", WIC64_SET_REMOTE_TIMEOUT, $01, $00, $05

timeout_error:            !pet "Transfer timeout", $d,$00
device_not_present_error: !pet "WIC64 not present or unresponsive", $d,$00
legacy_firmware_error:    !pet "Legacy firmware detected", $d,$00
legacy_firmware_hint:     !pet "Firmware 2.0.0 or later required", $d,$00
check_info:               !pet $d, "Checking WIC64", $d,0
connect_info:             !pet "Connected",$d,0
join_problem:             !pet $d,"Couldn't join",$d,0
communication_problem:    !pet $d,"Data couldn't be read/write",$d,0
join_cmd:                 !pet "join"  
run_cmd:                  !pet "run"
joy_up_cmd:               !pet "ju"
joy_down_cmd:             !pet "jd"
timeout_repeat:           !byte ACTION_REPEAT_NUMBER
  
ReadIP: !zone ReadIP {

; Zero page locations
BUF_PTR = $FB ; Pointer to the current position in the buffer

    ; Print the prompt message
    LDX #0
    STX buffer
    
.print_prompt:
    LDA .prompt_message, X
    BEQ .prompt_done
    JSR CHROUT
    INX
    BNE .print_prompt
.prompt_done:

    ; Initialize the buffer pointer
    LDX #0
    STX BUF_PTR

.read_loop:
    ; Read a character from the keyboard
    JSR CHRIN
    CMP #$0D ; Check if the character is RETURN
    BEQ .end_input

    ; Store the character in the buffer
    LDX BUF_PTR
    STA buffer, X
    INX
    STX BUF_PTR

    ; Check if the buffer is full
    CPX #BUFFER_SIZE
    BNE .read_loop

.end_input:
    ; Null-terminate the string
    LDX BUF_PTR
    LDA #0
    STA buffer, X

    ; End the program
    RTS

.prompt_message:
    !pet $d,"Enter server's IP:", 0
}

strlen: !zone strlen {

.STR_PTR = $FB ; Pointer to the current position in the string

    ; Initialize the string pointer
    STX .STR_PTR
    STY .STR_PTR+1

    ; Initialize the length counter
    LDY #0

.strlen_loop:
    ; Load the current character
    LDA (.STR_PTR), y
    ; Check if it is the null terminator
    BEQ .strlen_done
    ; Increment the length counter
    INY
    ; Continue to the next character
    JMP .strlen_loop

.strlen_done:
    ; Return the length in the A register
    TYA
    RTS
}  

ReadJoystick: !zone ReadJoystick {
    lda CIA1
    tay
    and #JOYUP
    beq .jup
    tya
    and #JOYDOWN
    beq .jdown
    rts
    
.jup:
    +send joy_up_cmd,2
    rts

.jdown:
    +send joy_down_cmd,2
    rts
}

ConvertToBinary: !zone ConvertToBinary {

        ldx bufptr
        lda #$00          ; Clear the accumulator
        sta buffer,x
        tax               ; X register will index the output buffer
        tay               ; Y register will index the input buffer
        sta temp_value_low
        sta temp_value_high ; Initialize temp_value to 0

.read_next_char:
        lda buffer,y     ; Load the next character from the input buffer
        bne +
        rts            ; If null terminator is reached, we're done

+       cmp #','          ; Check if the character is a comma
        beq .store_value  ; If so, store the current value

        cmp #'0'          ; Check if the character is a digit
        bcc .invalid_char ; If less than '0', it's invalid
        cmp #'9' + 1      ; Check if greater than '9'
        bcs .invalid_char ; If so, it's invalid

        pha

        ; Multiply temp_value by 10 (only if another digit follows)
        lda temp_value_low
        sta .buf
        lda temp_value_high
        sta .buf+1
        
        asl temp_value_low
        rol temp_value_high

        asl temp_value_low
        rol temp_value_high

        asl temp_value_low
        rol temp_value_high

        asl .buf
        rol .buf+1
        
        lda .buf
        clc
        adc temp_value_low
        sta temp_value_low
        lda .buf+1
        adc temp_value_high
        sta temp_value_high

        pla
        
        ; Convert ASCII digit to binary and add to temp_value
        sec
        sbc #'0'          ; Subtract ASCII '0' to get the digit
        clc
        adc temp_value_low
        sta temp_value_low

        lda temp_value_high
        adc #$00          ; Add carry to high byte
        sta temp_value_high

        iny               ; Move to the next character
        bne .read_next_char

.store_value:
        lda temp_value_low
        sta output_buffer,x
        inx
        lda temp_value_high
        sta output_buffer,x
        inx

        lda #$00
        sta temp_value_low
        sta temp_value_high
        iny
        jmp .read_next_char

.invalid_char:
        ; Handle invalid characters (optional)
        rts
        
        
.buf    !word 0
;buffer2: !text "300,6,21,65,111,222,", 0
output_buffer: !fill 12,0  ; x, y 2 bytes per value - ballx,bally,p1x,p1y,p2x,p2y,

; Variables
temp_value_low:  !byte 0  ; Low byte of the temporary value
temp_value_high: !byte 0  ; High byte of the temporary value
}
        
        
Start:

    lda #22
    sta 53272 ;lower case
    
    jsr ReadIP
    lda buffer
    bne +
    rts
    
+
    ldx #<buffer
    ldy #>buffer
    jsr strlen
    cmp #url_size
    beq +
    bcs Start
        
+
    ldx #0
-
    lda buffer,x
    beq +
    sta url,x
    inx
    bne -
    rts
    
+
    stx open_size
    jsr InitWIC64
    bcc +
    rts

+   

    jsr Connect
    bcc +
    rts

+
    +send join_cmd,4
    bcc +
    +print join_problem
    jmp Close
    
stop:
    +print communication_problem
    jmp Close
+
    jsr Read
    bcs stop
    lda buffer
    cmp #'o'
    beq game_start
    jmp Close

game_start:    
    
    jsr InitScreen
    
game_loop:

    +send run_cmd,3
    bcs stop
    jsr Read
    bcs stop
    lda buffer
    cmp #'e'
    beq game_loop
    
    jsr ConvertToBinary
    jsr RenderScreen
    jsr ReadJoystick
    jmp game_loop
    
InitScreen:

    lda #$93
    jsr CHROUT
    
    lda #%00000111  ;enable 3 sprites
    sta $d015
    lda #7          ;yellow
    sta $d027       ;sprite #0 color
    lda #3          ;cyan
    sta $d028       ;sprite #1 color
    lda #1          ;white
    sta $d029       ;sprite #2 color
    
    ldx #128  ;$2000
    stx $7fa
    inx
    stx $7f9
    inx
    stx $7f8 
    rts
    
RenderScreen:

    lda #$fe
-
    cmp $d012
    bne -
    
    lda #0
    sta $d010
    
    ; set ball (sprite #2)
    lda output_buffer+1
    beq +
    lda #%00000100
    sta $d010
+    
    lda output_buffer
    sta $d004
    lda output_buffer+2
    sta $d005
    
    ;player 1 (spr #0)
    lda output_buffer+5
    beq +
    lda #1    
    ora $d010
    sta $d010
+    
    lda output_buffer+4
    sta $d000
    lda output_buffer+6
    sta $d001
    
    ;player 2 (spr #1)
    lda output_buffer+9
    beq +
    lda #2    
    ora $d010
    sta $d010
+    
    lda output_buffer+8
    sta $d002
    lda output_buffer+10
    sta $d003    
    rts
    

response:

  * = $2000
  
;Spties data

!byte $30,$00,$00,$78,$00,$00,$FC,$00,$00,$78,$00,$00,$30,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01

!byte $00,$00,$07,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00
!byte $00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00
!byte $05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05
!byte $00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$05,$00,$00,$07,$01

!byte $E0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0
!byte $00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00
!byte $00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00
!byte $A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$A0,$00,$00,$E0,$00,$00,$01
