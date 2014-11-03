#include "p10F320.inc"

    processor pic10f320
    __config _FOSC_INTOSC & _BOREN_ON & _WDTE_OFF & _PWRTE_OFF & _MCLRE_ON & _CP_OFF & _LVP_ON & _LPBOR_ON & _BORV_LO & _WRT_OFF

    code 0x0000

reset
    movlw 0x00
    movwf LATA
    movlw 0x01
    movwf TRISA

_loop
    xorwf LATA, f
    goto _loop
    end
