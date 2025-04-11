; KERNAL routine addresses
CHROUT      = $FFD2
CHRIN       = $FFCF

CIA1        = $DC00

; Define the buffer size
BUFFER_SIZE = 255
ACTION_REPEAT_NUMBER = 6

JOYUP       = %00000001
JOYDOWN     = %00000010

!if BUFFER_SIZE > 255 {
  !error "BUFFER_SIZE cannot be greater than 255!"
}

!macro jcs .addr {
    bcc +
    jmp .addr
+
}

!macro jne .addr {
    beq +
    jmp .addr
+
}

!macro jeq .addr {
    bne +
    jmp .addr
+
}

!macro newline {
    lda #$37
    sta 1
    lda #$0d
    jsr CHROUT
}

!macro paragraph {
    lda #$37
    sta 1
    lda #$0d
    jsr CHROUT
    jsr CHROUT
}

!macro print .addr {
    lda #$37
    sta 1
    lda #<.addr
    ldy #>.addr
    jsr $ab1e
}

!macro send .data_ptr, .len {
  ldx #0
-
  lda .data_ptr,x
  sta payload,x
  inx
  cpx #.len
  bne -
  
  stx write_size
  jsr Write
}
