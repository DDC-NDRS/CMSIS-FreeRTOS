;/*
; * FreeRTOS Kernel V10.6.2
; * Copyright (C) 2021 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
; *
; * SPDX-License-Identifier: MIT
; *
; * Permission is hereby granted, free of charge, to any person obtaining a copy of
; * this software and associated documentation files (the "Software"), to deal in
; * the Software without restriction, including without limitation the rights to
; * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
; * the Software, and to permit persons to whom the Software is furnished to do so,
; * subject to the following conditions:
; *
; * The above copyright notice and this permission notice shall be included in all
; * copies or substantial portions of the Software.
; *
; * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
; * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
; * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
; * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
; * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
; *
; * https://www.FreeRTOS.org
; * https://github.com/FreeRTOS
; *
; */

    INCLUDE portmacro.inc

    IMPORT  vTaskSwitchContext
    IMPORT  xTaskIncrementTick

    EXPORT  vPortYieldProcessor
    EXPORT  vPortStartFirstTask
    EXPORT  vPreemptiveTick
    EXPORT  vPortYield


VICVECTADDR EQU 0xFFFFF030
T0IR        EQU 0xE0004000
T0MATCHBIT  EQU 0x00000001

    ARM
    AREA    PORT_ASM, CODE, READONLY



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Starting the first task is done by just restoring the context
; setup by pxPortInitialiseStack
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
vPortStartFirstTask

    PRESERVE8

    portRESTORE_CONTEXT

vPortYield

    PRESERVE8

    SVC 0
    bx lr

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for the SWI interrupt.  The vector table is
; configured in the startup.s file.
;
; vPortYieldProcessor() is used to manually force a context switch.  The
; SWI interrupt is generated by a call to taskYIELD() or portYIELD().
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vPortYieldProcessor

    PRESERVE8

    ; Within an IRQ ISR the link register has an offset from the true return
    ; address, but an SWI ISR does not.  Add the offset manually so the same
    ; ISR return code can be used in both cases.
    ADD LR, LR, #4

    ; Perform the context switch.
    portSAVE_CONTEXT                    ; Save current task context
    LDR R0, =vTaskSwitchContext         ; Get the address of the context switch function
    MOV LR, PC                          ; Store the return address
    BX  R0                              ; Call the contedxt switch function
    portRESTORE_CONTEXT                 ; restore the context of the selected task



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt service routine for preemptive scheduler tick timer
; Only used if portUSE_PREEMPTION is set to 1 in portmacro.h
;
; Uses timer 0 of LPC21XX Family
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

vPreemptiveTick

    PRESERVE8

    portSAVE_CONTEXT                    ; Save the context of the current task.

    LDR R0, =xTaskIncrementTick         ; Increment the tick count.
    MOV LR, PC                          ; This may make a delayed task ready
    BX R0                               ; to run.

    CMP R0, #0
    BEQ SkipContextSwitch
    LDR R0, =vTaskSwitchContext         ; Find the highest priority task that
    MOV LR, PC                          ; is ready to run.
    BX R0
SkipContextSwitch
    MOV R0, #T0MATCHBIT                 ; Clear the timer event
    LDR R1, =T0IR
    STR R0, [R1]

    LDR R0, =VICVECTADDR                ; Acknowledge the interrupt
    STR R0,[R0]

    portRESTORE_CONTEXT                 ; Restore the context of the highest
                                        ; priority task that is ready to run.
    END
