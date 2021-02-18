        .code32
        .globl  _start
_start:
        /*
         * - Here IF flag is off and NMI is disabled
         * - %esp is still the same value which was set in the first loader
         * - CS, DS, ES, FF, GS and SS selectors point to 32-bit flat address
         *   segments
         */

        calll   kernel_main

        /* Should never return here */
        cli
1:
        hlt
        jmp     1b
