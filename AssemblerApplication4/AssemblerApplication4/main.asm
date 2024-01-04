.include "m328pdef.inc"
.include "delay_Macro.inc"
.include "UART_Macros.inc"
.include "div_Macro.inc"

.cseg

.def temperature = r16        
.def temp_high_byte = r17    
.def FlameCheck = r18
.def ThermalCheck = r19
.equ Led1 = PB5              ; Define Led1 as PB5
.equ Buzzeer = PD7           ; Define Buzzeer as PD7
.equ FlameSensorInput = PD5  ; Define FlameSensorInput as PD5

.org 0x0000

    SBI DDRB, Led1       ; Led1 (PB5) set as OUTPUT Pin
    CBI PORTB, Led1      ; Led1 (PB5) OFF
    CBI DDRD, FlameSensorInput ; PD5 set as INPUT pin

    SBI DDRD, Buzzeer        ; Buzzeer set as OUTPUT Pin
    CBI PORTD, Buzzeer       ; Buzzer OFF

   

    ; ADC Configuration
    LDI   temperature, 0b11000111  ; [ADEN ADSC ADATE ADIF ADIE ADIE ADPS2 ADPS1 ADPS0]
    STS   ADCSRA, temperature
    LDI   temperature, 0b01100000  ; [REFS1 REFS0 ADLAR � MUX3 MUX2 MUX1 MUX0]
    STS   ADMUX, temperature       ; Select ADC0 (PC0) pin
    ; SBI   PORTC,PC0            ; Enable Pull-up Resistor

    Serial_begin        ; Initialize UART serial communication

loop:
    delay 1000

    call loadThermalVal
    Serial_writeReg_ASCII temp_high_byte   ; Sending the received value to ESP
    cpi temp_high_byte, 138  ; Compare LDR reading with our desired threshold
    brlo OnThermalOn    ; Jump if less than (temp_high_byte < 135)
	; If temperature is cold / low --> val == high
	LDI ThermalCheck,0
    CBI PORTB, Led1     ; Led1 OFF
	rjmp flameSection

    ; On high temperature
OnThermalOn:
    SBI PORTB, Led1     ; Led1 ON
	LDI ThermalCheck, 1
    cpi temp_high_byte, 110  ; Compare LDR reading with our desired threshold
    brsh FlameSection    ; Jump if greater than

FlameSection:
    ; Check if flame is On
    SBIC PIND, FlameSensorInput ; If flame is 0, skip the next line
    rjmp IfFlameOn
    ; If flame is not on
    LDI FlameCheck, 0     ; 
    rjmp EndLoop

    ; If flame is on
IfFlameOn:
    SBI PORTB, Led1      ; Led1 ON
    LDI FlameCheck, 1

EndLoop:
    
    Serial_writeChar '-'     ;To differentiate for Flame values

    cpi FlameCheck, 1
    breq onBuzzerOn
    cpi ThermalCheck, 1
    breq onBuzzerOnBeep
    Serial_writeChar '0'
    rjmp onBuzzerOff

onBuzzerOn :
    Serial_writeChar '1'
    SBI PORTD, Buzzeer       ; Buzzer On
	rjmp buzzerskip

onBuzzerOnBeep :
    Serial_writeChar '1'
    SBI PORTD, Buzzeer       ; Buzzer On
	delay 10
	CBI PORTD, Buzzeer
	delay 10
	rjmp buzzerskip

onBuzzerOff:
	CBI PORTD, Buzzeer

	buzzerskip:
	Serial_writeNewLine
ReadFromEsp:
    LDI r16, 0
    ; Check UART serial input buffer for any incoming data and place it in r16
    Serial_read
    ; If there is no data received in UART serial buffer (r16 == 0)
    ; then don't send it to UART
    CPI r16, 0
    BREQ skip_UART

    CPI r16, 'B'
    breq externalTurnBuzzerOff

    SBI PORTD, Buzzeer       ; Buzzer On
    LDI ThermalCheck, 1
    LDI FlameCheck, 1
    ; delay 2000

    rjmp skip_UART

externalTurnBuzzerOff:
    CBI PORTD, Buzzeer       ; Buzzer OFF
    LDI ThermalCheck, 0
    LDI FlameCheck, 0

skip_UART:
    rjmp loop

loadThermalVal:
    LDS temperature, ADCSRA    ; Start Analog to Digital Conversion 
    ORI temperature, (1<<ADSC)
    STS ADCSRA, temperature

wait:
    LDS temperature, ADCSRA    ; Wait for ADC conversion to complete
    sbrc temperature, ADSC
    rjmp wait

    LDS temperature, ADCL       ; Must Read ADCL before ADCH
    LDS temp_high_byte, ADCH

ret
