#include "p10F320.inc"

    processor pic10f320
    __config _FOSC_INTOSC & _BOREN_ON & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _LVP_ON & _LPBOR_ON & _BORV_LO & _WRT_OFF

    code 0x0000

reset
    goto init

send
    movwf 0x40

    rrf LATA, W
    movwf 0x41

    bcf LATA, 0

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    rrf 0x40, F
    rlf 0x41, W
    movwf LATA

    nop
    nop
    bsf LATA, 0

    nop
    return

init
    bsf LATA, 0
    bcf ANSELA, 0
    bcf TRISA, 0

    movlw (1<<ADCS1) | (1<<ADCS0) | (1<<CHS1) | (1<<ADON)
    movwf ADCON

main
    movlw 0x10

    movwf 0x40
_nop_wait
    decfsz 0x40, F
    goto _nop_wait

    bsf ADCON, GO_NOT_DONE
_adc_wait
    btfsc ADCON, GO_NOT_DONE
    goto _adc_wait

    movfw ADRES
    call send
    goto main
    end
