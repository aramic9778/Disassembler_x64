*-----------------------------------------------------------
* Title      : Disassembler I/O
* Written by : Dat H. Tran (Skye Leblanc)
* Date       : 10th Nov. 2021
* Description: Prompt user input for disassembling. Output disassembled code.
*-----------------------------------------------------------
CR                  EQU     $0D                     ; ASCII code for carriage return
LF                  EQU     $0A                     ; ASCII code for line feed
StackPtsInit        EQU     $8000                   ; Stack pointer initializes at address $8000
ClearScreenCoor     EQU     $FF00                   ; Select row, col to clear screen
OutputSize          EQU     20                      ; Only output 20 lines per enter

AddrMinLength       EQU     1                       ; Address length must between 1 and 8
AddrMaxLength       EQU     8                       ;

ASCII_Space         EQU     $20                     ; ASCII code for space
ASCII_DollarSign    EQU     $24                     ; ASCII code for $
ASCII_Zero          EQU     $30                     ; ASCII code for number 0
ASCII_Nine          EQU     $39                     ; ASCII code for number 9
ASCII_LetterA       EQU     $41                     ; ASCII code for letter A
ASCII_LetterD       EQU     $44                     ; ASCII code for letter D
ASCII_LetterF       EQU     $46                     ; ASCII code for letter F
ASCII_LetterR       EQU     $52                     ; ASCII code for letter R
ASCII_LetterT       EQU     $54                     ; ASCII code for letter T
ASCII_Letter_r      EQU     $72                     ; ASCII code for letter r

                    ORG     $1000
START                                               ; Main driver
                    LEA     StackPtsInit,SP         ; Initialize stack pointer value
                    JSR     OutputEnterMsg          ; 
                    JSR     OutputWelcomeMsg        ; 
                    JSR     OutputInstruction       ; 
                    
StartPrompt         JSR     PromptStartAddr         ; Return start address in A0
                    JSR     PromptEndAddr           ; Return end address in A3
                    JSR     ValidateAddrRange       ; Continue if pass validation check
                    JSR     OutputEnterMsg          ; 
                    
WaitForEnterKey     CLR.L   D2                      ; Reset output buffer
                    JSR     OutputPressEnterMsg     ; Prompt to begin disassembling
                    JSR     PromptEnterMsg          ; 

MainLoop            CMP.L   A3,A0                   ; While current address <= ending address
                    BHI     EndProgram
                    
                    CMP.L   #OutputSize,D2          ; Prevent output when page output buffer reaches
                    BEQ     WaitForEnterKey         ; 

ContParsing         ADDQ    #1,D2                   ; Increment line-output counter

                    JSR     PreParseOpcodeProc      ; 
                    JSR     ParseOpcodeProc         ; 
                    JSR     PostParseOpcodeProc     ; 
                    
EndProgram          JSR     OutputEndProgramMsg     ;
                    JSR     OutputEndProgActMsg     ; 
                    JSR     PromptAnyChar           ; 
                    JSR     HandleEndProgAct        ; 
                    
*** Grouping Functions: Refactoring & Organization
PromptStartAddr     JSR     OutputStartAddrMsg      ; Prompt user for start address input
                    JSR     RetrieveStartAddr       ; 
                    JSR     ValidateAddr            ; Check starting address
                    
                    LEA     StartAddr,A4            ; Convert input address into hexadecimal
                    JSR     ConvertInputToHex       ; Result is in A6
                    JSR     ValidateAddrWAlign      ; 
                    MOVEA.L A6,A0                   ; Store start address in A0
                    
                    RTS                             ; 

*** Helper Functions: Retrieve prompted input start address from user
RetrieveStartAddr   LEA     StartAddr,A1            ; Load start address storage
                    MOVE.B  #2,D0                   ; Store user prompt in A1
                    TRAP    #15                     ; Start address' length is in D1
                    
                    CLR.L   D0                      ; Clean up
                    RTS                             ; 

*** Grouping Functions: Refactoring & Organization                    
PromptEndAddr       JSR     OutputEndAddrMsg        ; Prompt user for end address input
                    JSR     RetrieveEndAddr         ; 
                    JSR     ValidateAddr            ; Check ending address
                    
                    LEA     EndAddr,A4              ; Convert input address into hexadecimal
                    JSR     ConvertInputToHex       ; Result is in A6
                    JSR     ValidateAddrWAlign      ; 
                    MOVEA.L A6,A3                   ; Store end address in A3
                    
                    RTS                             ; 

*** Grouping Functions: Refactoring & Organization
*** Input: start address in A0, end address in A3
*** Return: Null
ValidateAddrRange   CMPA.L  A3,A0                   ; Check if start address <= end address
                    BHI     HandleAddrRangeErr      ; 
                    RTS                             ;    

*** Helper Functions: Retrieve prompted input end address from user
RetrieveEndAddr     LEA     EndAddr,A1              ; Load end address storage
                    MOVE.B  #2,D0                   ; Store user prompt in A1
                    TRAP    #15                     ; End address' length is in D1
                    
                    CLR.L   D0                      ; Clean up
                    RTS

*** Helper Functions: Prompt input address from user --- Validate if address is word-aligned
ValidateAddrWAlign  MOVE.L  A6,D6                   ; Move to data register to perform bit test for word boundary
                    BTST.L  #0,D6                   ; Word boundary validation
                    BNE     HandleAddrWBoundErr     ; 
                    
                    CLR.L   D6                      ; Clean up
                    RTS                             ; 
                    
*** Auxilary Functions: Address validation
ValidateAddr        CMP.B   #AddrMinLength,D1       ; Check input address length
                    BLT     HandleAddrLengthErr     ; Must be between 1 and 8
                    CMP.B   #AddrMaxLength,D1       ;
                    BGT     HandleAddrLengthErr     ;
                    
                    MOVE.B  #0,D3                   ; D3 is loop counter
LoopValidateAddr    CMP.B   D1,D3                   ; D2 stores individual token
                    BEQ     EndValidateAddr         ; D1 is loop's upper boundary
                    
                    MOVE.B  (A1)+,D2                ; Get next token
                    
                    CMP.B   #ASCII_ZERO,D2          ; Check if token is within the lower bound
                    BLT     HandleAddrCharErr       ; 
                    CMP.B   #ASCII_LetterF,D2       ; Check if token is within the upper bound
                    BGT     HandleAddrCharErr       ;
                    
                    CMP.B   #ASCII_LetterA,D2       ; Check if token is possible number or letter
                    BLT     ValidateNumToken        ; Identify a possible number, continue validation
                    BRA     IncrementLoop           ; If reach here, address is valid
                    
ValidateNumToken    CMP.B   #ASCII_NINE,D2          ; Check if number is valid
                    BGT     HandleAddrCharErr       ;

IncrementLoop       ADDQ    #1,D3                   ; Increment loop counter
                    BRA     LoopValidateAddr        ;

EndValidateAddr     CLR.L   D2                      ; Clean up
                    CLR.L   D3                      ; 
                    SUBA.L  A1,A1                   ;
                    RTS                             ; 

*** Grouping Functions: Refactoring & Organization
PreParseOpcodeProc  LEA     OutputBuffer,A2         ; Set output buffer to A2
                    
                    CMP.L   #1,D2                   ; 
                    BEQ     MakeScreenBlank         ;  
                    
ContPreParseOpcode  MOVEA.L A0,A6                   ; store copy of current address when bad flag occurs
                    JSR     AddCurrAddrToOutBuf     ; 
                    CLR.L   D0                      ; Clear bad flag
                    RTS                             ; 

MakeScreenBlank     JSR     OutputBlankScreen       ; 
                    BRA     ContPreParseOpcode      ; 
                    
*** Load the current address to the output buffer
*** Input:  current address in A0
*** Return: NULL
*** Modify: A2, A5, D3, D4, D5
AddCurrAddrToOutBuf CLR.L   D3                      ; Clear loop counter
                    MOVE.L  A0,D4                   ; 

AddAddrChrLoop      CMP.B   #8,D3                   ; Loop over all hex character of current address
                    BEQ     EndAddCurrAddr          ; 

                    JSR     AddNextChr2OutBuf       ; 
                    
                    ADDQ    #1,D3                   ; Increment loop counter                    
                    BRA     AddAddrChrLoop          ; 

EndAddCurrAddr      CLR.L   D3                      ; Clean up

                    JSR     AddTabToOutBuf          ; 
                    RTS                             ; 

*** Helper Functions: Add next character to output buffer
*** Input:  current address (D4)
*** Return: next character  (A2)
AddNextChr2OutBuf   JSR     ExtractNextAddrChr      ; Next address character in A5
                    MOVE.B  (ASCII_LookUp,A5),(A2)+ ; Add current address character in output buffer
                    SUBA.L  A5,A5                   ; Clean up
                    RTS                             ; 

*** Helper Functions: Extract next character
*** Input:  current address (D4)
*** Return: next character  (A5)
ExtractNextAddrChr  ROL.L   #4,D4                   ; 
                    MOVE.B  D4,D5                   ; 
                    AND     #FirstNibbleMask,D5     ; 
                    MOVEA   D5,A5                   ; 
                    CLR.L   D5                      ; Clean up
                    RTS                             ; 

*** Helper Functions: Add tab to output buffer (A2)
*** Input: A2
*** Return: A2
AddTabToOutBuf      CLR.L   D3                      ; Reset loop counter
                    
LoopSpace           CMP.B   #4,D3                   ; Total of 4 spaces to make 1 tabs
                    BEQ     EndFillSpace            ; 
                    
                    ADDQ    #1,D3                   ; Increment loop counter
                    MOVE.B  #ASCII_Space,(A2)+      ; 
                    
                    BRA     LoopSpace               ; 

EndFillSpace        CLR.L   D3                      ; Clean up
                    RTS                             ;

*** Grouping Functions: Refactoring & Organization
ParseOpcodeProc     MOVEM.L D1-D7/A1/A3-A6,-(SP)    ; Save registers except A0, A2, D0
                    JSR     OPCODE_PART                ; Call opcodes
                    MOVEM.L (SP)+,D1-D7/A1/A3-A6    ; Restore registers except A0, A2, D0
                    RTS                             ; 

*** Grouping Functions: Refactoring & Organization
PostParseOpcodeProc CMP.B   #0,D0                   ; Check bad flag
                    BEQ     HandleGoodFlag          ; Output is clean
                    BRA     HandleBadFlag           ; Output is dirty

*** Helper Functions: PostParseOpcodeProc
HandleGoodFlag      JSR     AddNullTerm2OutBuf      ; 
                    JSR     PrintOutBuf2Console     ; 
                    BRA     MainLoop                ; 

*** Helper Functions: PostParseOpcode
AddNullTerm2OutBuf  MOVE.B  #0,(A2)+                ; 
                    RTS                             ; 
                  
* print a disassembled instructions to the user
PrintOutBuf2Console LEA     OutputBuffer,A1         ; Display output buffer to console
                    MOVE.B  #0,D0                   ; 
                    JSR     GetLastStrLength        ; Store in D1, ready for output
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    CLR.L   D1                      ; 
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

*** Helper Functions: Calculate number of characters in the
***                   current output buffer after parsing the
***                   last opcode
*** Input:  current address (A2), output buffer
*** Output: output buffer length (D1)
GetLastStrLength    MOVEA.L A2,A5                   ; 
                    SUBA    OutputBuffer,A5         ; 
                    MOVE.W  A5,D1                   ; 
                    SUBA.L  A5,A5                   ; Clean up
                    RTS                             ; 

* Handles Bad Flag Routine: Clear output and replace with error messages
HandleBadFlag       JSR     ResetBadFlag            ; 
                    JSR     BeginOverwriting        ; 
                    JSR     SkipAddressLocation     ; 
                    JSR     AddPlaceholderOp        ; 
                    JSR     FillEmptySpace          ; 
                    JSR     AddDollarSign           ; 
                    JSR     GetInstructionWord      ; 
                    JSR     AddToOutBuf             ; 
                    JSR     AddNullTerm2OutBuf      ; 
                    JSR     PrintOutBuf2Console     ; 
                    BRA     MainLoop                ; 

*** Helper Functions: HandleBadFlag
ResetBadFlag        CLR.L   D0                      ; 
                    RTS                             ; 
                    
*** Helper Functions: HandleBadFlag
BeginOverwriting    LEA     OutputBuffer,A2         ; 
                    RTS                             ; 
                    
*** Helper Functions: HandleBadFlag
SkipAddressLocation ADDA    #12,A2                  ; 
                    RTS                             ; 
                    
*** Helper Functions: HandleBadFlag
AddPlaceholderOp    MOVE.B  #ASCII_LetterD,(A2)+    ; 
                    MOVE.B  #ASCII_LetterA,(A2)+    ; 
                    MOVE.B  #ASCII_LetterT,(A2)+    ; 
                    MOVE.B  #ASCII_LetterA,(A2)+    ; 
                    RTS                             ; 

*** Helper Functions: HandleBadFlag
FillEmptySpace      CLR.L   D3                      ; Reset loop counter
                    
LoopEmptySpace      CMP.B   #7,D3                   ; Total of 7 spaces
                    BEQ     EndFillEmptySpace       ; 
                    
                    ADDQ    #1,D3                   ; Increment loop counter
                    MOVE.B  #ASCII_Space,(A2)+      ; 
                    
                    BRA     LoopEmptySpace          ; 

EndFillEmptySpace   CLR.L   D3                      ; Clean up
                    RTS                             ;

*** Helper Functions: HandleBadFlag
AddDollarSign       MOVE.B  #ASCII_DollarSign,(A2)+ ; 
                    RTS                             ; 

*** Helper Functions: HandleBadFlag
GetInstructionWord  MOVE.W  (A6),D1                 ; Get last address pointer
                    LSL.L   #$08,D1                 ; 
                    LSL.L   #$08,D1                 ; 
                    RTS                             ; 

*** Helper Functions: HandleBadFlag
AddToOutBuf         CLR.L   D3                      ; Reset loop counter

LoopAddToOutBuf     CMP.B   #4,D3                   ; Total 4 hexadecimal characters
                    BEQ     EndAddToOutBuf          ; 
                    
                    ADDQ    #1,D3                   ; 
                    JSR     AddInstructionChr       ; 
                    BRA     LoopAddToOutBuf         ; 
                    
EndAddToOutBuf      CLR.L   D3                      ; Clean up 
                    RTS                             ; 

*** Helper Functions: AddToOutBuff
AddInstructionChr   JSR     GetInstructionChr       ; Result in A5
                    MOVE.B  (ASCII_LookUp,A5),(A2)+ ; Add instruction character to output buffer
                    SUBA.L  A5,A5                   ; Clean up
                    RTS                             ; 

*** Helper Functions: AddInstructionChr
GetInstructionChr   ROL.L   #4,D1                   ; Extract an instruction character
                    MOVE.B  D1,D4                   ; Parse
                    AND     #FirstNibbleMask,D4     ; 
                    MOVEA   D4,A5                   ; 
                    CLR.L   D4                      ; Clean up 
                    RTS                             ; 

HandleEndProgAct    CMP.B   #ASCII_LetterR,D1       ; Check if input is R
                    BEQ     RestartDisassembler     ; 
                    
                    CMP.B   #ASCII_Letter_r,D1      ; Check if input is r
                    BEQ     RestartDisassembler     ; 
                    
                    BNE     EndDisassembler         ; 

RestartDisassembler JSR     OutputBlankScreen       ;
                    JSR     ResetAllRegisters       ; 
                    BRA     START                   ; 
                    
EndDisassembler     JSR     OutputBlankScreen       ;
                    JSR     OutputStopMsg           ; 
                    STOP    #3000                   ; 
                    
*** Helper Functions: Reset entire program          ; 
ResetAllRegisters   CLR.L   D0                      ; 
                    CLR.L   D1                      ; 
                    CLR.L   D2                      ; 
                    CLR.L   D3                      ; 
                    CLR.L   D4                      ; 
                    CLR.L   D5                      ; 
                    CLR.L   D6                      ; 
                    CLR.L   D7                      ; 
                    
                    SUBA.L  A0,A0                   ; 
                    SUBA.L  A1,A1                   ; 
                    SUBA.L  A2,A2                   ; 
                    SUBA.L  A3,A3                   ; 
                    SUBA.L  A4,A4                   ; 
                    SUBA.L  A5,A5                   ; 
                    SUBA.L  A6,A6                   ; 
                    
                    RTS                             ; 

*** IO Error Handling Functions
HandleAddrLengthErr JSR     OutputAddrLengthErr     ; 
                    JSR     ResetInputError         ; 
                    JSR     OutputEnterMsg          ; 
                    BRA     StartPrompt             ; 

*** IO Error Handling Functions
HandleAddrCharErr   JSR     OutputAddrCharErr       ; 
                    JSR     ResetInputError         ; 
                    JSR     OutputEnterMsg          ; 
                    BRA     StartPrompt             ; 

*** IO Error Handling Functions
HandleAddrWBoundErr JSR     OutputAddrWBoundErr     ; 
                    JSR     ResetInputError         ; 
                    JSR     OutputEnterMsg          ; 
                    BRA     StartPrompt             ; 

*** IO Error Handling Functions
HandleAddrRangeErr  JSR     OutputAddrRangeErr      ; 
                    JSR     ResetInputError         ; 
                    JSR     OutputEnterMsg          ; 
                    BRA     StartPrompt             ; 

*** Helper Functions: IO Error Handling Functions
ResetInputError     CLR.L   D0                      ; 
                    CLR.L   D1                      ; 
                    CLR.L   D2                      ; 
                    CLR.L   D3                      ; 
                    CLR.L   D4                      ; 
                    CLR.L   D5                      ; 
                    CLR.L   D6                      ; 
                    CLR.L   D7                      ; 
                    
                    SUBA.L  A1,A1                   ;
                    SUBA.L  A4,A4                   ; 
                    SUBA.L  A5,A5                   ; 
                    SUBA.L  A6,A6                   ;

                    RTS                             ; 

*** Auxilary Functions: Convert string input to hexadecimal formal
*** A4 contains starting address of string input
*** D1 contains the length of string input
*** RETURN: A6
                                                    ; D7 is hexadecimal buffer
ConvertInputToHex   MOVE.B  #0,D3                   ; D3 is loop counter
                                                    ; D2 stores next token
ConvertLoop         CMP.B   D1,D3                   ; D1 is loop's upper boundary
                    BEQ     EndConvert              ;
                    
                    ADDQ.B  #1,D3                   ; Increment counter
                    LSL.L   #4,D7                   ; Shift left for next hexadecimal token
                    
                    MOVE.B  (A4)+,D2                ; Get next token
                    
                    CMP.B   #ASCII_NINE,D2          ; Check if token is a digit
                    BLE     GetDigit                ;
                    
                    CMP.B   #ASCII_LetterA,D2       ; Check if token is a letter
                    BGE     GetChar                 ;
                    
GetDigit            SUB.B   #ASCII_ZERO,D2          ; Convert to digit
                    ADD.B   D2,D7                   ;
                    BRA     LoopCounter             ;

GetChar             SUB.B   #$37,D2                 ; Convert to char
                    ADD.B   D2,D7                   ;

LoopCounter         BRA     ConvertLoop             ;
                    
EndConvert          MOVEA.L D7,A6                   ; Move translated address to A6
                    
                    CLR.L   D1                      ; Clean up
                    CLR.L   D2                      ; 
                    CLR.L   D3                      ; 
                    CLR.L   D7                      ; 
                    SUBA.L  A4,A4                   ; 
                    RTS                             ; 

*** Auxilary Functions: Output messages
OutputWelcomeMsg    LEA     WelcomeMsg,A1           ; Output welcome message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputInstruction   JSR     OutputIMsg0             ; 
                    JSR     OutputIMsg1             ; 
                    JSR     OutputIMsg2             ; 
                    RTS                             ; 
                    
OutputIMsg0         LEA     InstructionMsg0,A1      ; Output first part of the instruction message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 
                    
OutputIMsg1         LEA     InstructionMsg1,A1      ; Output second part of the instruction message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputIMsg2         LEA     InstructionMsg2,A1      ; Output third part of the instruction message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ;                     

OutputStartAddrMsg  LEA     PromptStartAddrMsg,A1   ; Output prompt message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputEndAddrMsg    LEA     PromptEndAddrMsg,A1     ; Output prompt message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputPressEnterMsg LEA     PromptForEnterMsg,A1    ; Output prompt message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputEndProgramMsg LEA     EndProgramMsg,A1        ; Output end program message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ;
                    RTS                             ; 

OutputEndProgActMsg LEA     EndProgramActionMsg,A1  ; Output end program action message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS

OutputStopMsg       LEA     StopMsg,A1              ; Output stop message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputAddrLengthErr LEA     AddrLengthError,A1      ; Output error message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 
                    
OutputAddrWBoundErr LEA     AddrWordBoundError,A1   ; Output error message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 

OutputAddrCharErr   LEA     AddrCharError,A1        ; Output error message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 
               
OutputAddrRangeErr  LEA     AddrRangeError,A1       ; Output error message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ;

OutputEnterMsg      LEA     EnterMsg,A1             ; Output enter message
                    MOVE.B  #14,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 
                    
OutputBlankScreen   MOVE.W  #ClearScreenCoor,D1     ; 
                    MOVE.B  #11,D0                  ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    CLR.L   D1                      ; 
                    RTS                             ; 
                    
PromptEnterMsg      LEA     EnterMsg,A1             ; Prompt ENTER key
                    MOVE.B  #2,D0                   ; 
                    TRAP    #15                     ; 
                    CLR.L   D0                      ; Clean up
                    SUBA.L  A1,A1                   ; 
                    RTS                             ; 
                    
PromptAnyChar       MOVE.B  #5,D0                   ; Only take one character
                    TRAP    #15                     ; Result in D1.B
                    CLR.L   D0                      ; Clean up
                    RTS                             ; 

*** Prompt messages
WelcomeMsg          DC.B    'CSS 422: Hardware & Computer Organization',CR,LF,'Welcome to Yeetus Disassembler Program!',CR,LF,'Made by: Skye Tran, Aram Antonyan, Tiffany Chen, and Phillip Burlachenko!',CR,LF,CR,LF,0
InstructionMsg0     DC.B    'READ ME: User guide instruction',CR,LF,0
InstructionMsg1     DC.B    'Addresses must be 1 to 8 hexadecimal characters, [0-9][A-F]',CR,LF,'The last hexadecimal character must be divisible by 2, [0, 2, 4, 6, 8, A, C, E]',CR,LF,'The starting address must be greater than $1000.',CR,LF,0
InstructionMsg2     DC.B    'The ending address must be greater than the starting address.',CR,LF,CR,LF,0
PromptStartAddrMsg  DC.B    'Please enter the starting address, then press ENTER key to continue: ',0
PromptEndAddrMsg    DC.B    'Please enter the ending address, then press ENTER key to continue: ',0
PromptForEnterMsg   DC.B    'Press ENTER key to get the next disassembled code...',0
EndProgramMsg       DC.B    'Disassemble successfully!',CR,LF,0
EndProgramActionMsg DC.B    'Press R or r to RESTART. Press ANY other keys to STOP...',0
StopMsg             DC.B    'Disassembler terminates!',0

*** Error messages
AddrLengthError     DC.B    'ERROR: Invalid input. Address must range between 1 to 8 characters',CR,LF,0
AddrCharError       DC.B    'ERROR: Invalid input. Address must contain only 0-9 and A-F only',CR,LF,0
AddrWordBoundError  Dc.B    'ERROR: Invalid input. Address must be word-aligned / divisible by four',CR,LF,0
AddrRangeError      DC.B    'ERROR: Invalid input. Start address must be less than or equal to end address.',CR,LF,0

*** Auxilary messages
EnterMsg            DC.B    '',CR,LF,0

*** Variables
StartAddr           DS.L    1
EndAddr             DS.L    1
OutputBuffer        DCB.B   84,0
FirstNibbleMask     EQU     %00001111               
ASCII_LookUp        DC.B    $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46


*-----------------------------------------------------------
* Title      : Op-Code Subroutines
* Written by : Ting-Shiuan Chen & Phillip Burlachenko
* Date       : 11/13/2021
* Description: Opcode
*-----------------------------------------------------------

CR          EQU        $0D                  *ASCII coed for Carriage Return
LF          EQU        $0A                  *ASCII code for Line Feed

* first instruction of OP-code program
****Opcode Start************************************************
OPCODE_PART MOVE.W    (A0)+,D1        * Read opcode into D1
            MOVE.L    A2,OP_str_Star       *Storing starting string address in orign_OP variable              

***************************************************************
****Checking Opcode ********************************************
***************************************************************
*-----Check whether machine code is NOP/RTS or not
            *NOP/RTS
            CMP.W   Hex_NOP, D1             *directly using hex to check NOP & RTS
            BEQ     NOP                     *NOP/RTS is fixed machine code
            
            CMP.W   Hex_RTS, D1             
            BEQ     RTS
            
*-----Decision Tree-----------------------
TreeStart   BTST    #15, D1
            BNE     ONE                     *if #15 is one then branch to one part
            BEQ     Zero

     
            * #15 is Zero
            *MOVEA MOVE MOVEM NOT ADDQ JSR LEA
            *BRA BEQ BGT BLE MOVEQ 
Zero        BTST    #14, D1                 
            BNE     ONE_14
            BRA     Zero_14
            
            *MOVEM NOT ADDQ JSR LEA 
            *BEQ BGT BLE MOVEQ 
ONE_14      BTST    #12, D1
            BNE     ONE_12
            BRA     Zero_12

*-----------MOVE, MOVEA----------------------------
Zero_14     MOVE.W  D1, D2
            AND.W   #$01C0, D2              *check #8, 7, 6 == 001

            CMP.W   #$0040, D2
            BEQ     MOVEA
            
            BNE     MOVE
*-----------MOVEQ ADDQ------------------------------
ONE_12      BTST    #8, D1                  *check #8 is 0 or 1
            BNE     INVALID
            
            BTST    #13, D1                 *check #13 is 0 or 1
            BEQ     ADDQ
            BNE     MOVEQ
*-----------BRA BEQ BGT BLE  MOVEM NOT JSR LEA--------
            *B_Group: BRA BEQ BGT BLE
Zero_12     
            MOVE.W  D1, D2
            AND.W   #$F000, D2              *check #15 to #12 == 0110
            CMP.W   #$6000, D2
            BEQ     B_Group
            
            *Not_B_group:MOVEM NOT JSR LEA-
            CMP.W   #$4000, D2              *#15 to #12 == 0010
            BEQ     NOT_B_Group
            
            *BRA
B_Group     CLR     D2
            MOVE.W  D1, D2
            AND.W   #$0F00, D2              *check #11 to #8 == 0000
            CMP.W   #$0000, D2
            BEQ     BRA
            
            *BEQ
            CMP.W   #$0700, D2              *check #11 to #8 == 0111
            BEQ     BEQ
            
            *BGT
            CMP.W   #$0E00, D2              *check #11 to #8 == 1110
            BEQ     BGT
            
            *BLE
            CMP.W   #$0F00, D2              *check #11 to #8 == 1111
            BEQ     BLE
                        
*-----------Not B_group-------------------------------------------
            *Not_B_group:MOVEM NOT JSR LEA-
            *NOT
NOT_B_Group CLR     D2
            MOVE.W  D1, D2
            AND.W   #$0F00, D2
            CMP.W   #$0600, D2              *check #11 to #8 == 0110
            BEQ     NOT

            *JSR
            CMP.W   #$0E00, D2              *check #11 to #8 == 1110
            BNE     C_LEA                   *checking LEA & MOVEM
            CLR     D2
            MOVE.W  D1, D2
            AND.W   #$00C0, D2
            CMP.W   #$0080, D2              *check #8 to #7 == 10
            BEQ     JSR
              
            *LEA 
C_LEA       CLR     D2
            MOVE.W  D1, D2
            ROR.W   #1, D2
            AND.W   #$00E0, D2              *check #8, 7, 6 == 111
            CMP.W   #$00E0, D2
            BEQ     LEA
            
            *MOVEM
            CLR     D2
            MOVE.W  D1, D2
            ROL.W   #1, D2
            AND.W   #$0700, D2              *check #9, 8, 7 == 001
            CMP.W   #$0100, D2
            BEQ     MOVEM
            BNE     INVALID
*---------------------------------------------------------------
*-----------#15 bit is One-----------------------------------------
*---------------------------------------------------------------
ONE         BTST    #14,D1
            BEQ     ZERO14                 *if 0 
            BRA     ONE14                  *else 1 
    
*OR SUB
ZERO14      BTST    #12,D1
            BEQ     OR                   *if 0 
            BRA     SUB                  *if 1 
*AND ADD ADDA ASR LSR ROR ASL LSL ROL  
ONE14
            BTST    #13,D1 
            BNE     ROTATION                *if 1 ASR LSR ROR ASL LSL ROL
            BNE     INVALID
            
            BTST    #12,D1
            BEQ     ZERO12                  *if 0 we know its AND
    
            *otherwise ADD or ADDA
            CLR     D2
            MOVE.W  MB_6_7,D2               *load mask bits #6, 7
            AND.W   D1,D2                   *mask bits
            CMP.W   MB_6_7,D2               *if 0,d2 bits #6, 7 are 11
            BNE     ADD                     *if not 0, its ADD
            BRA     ADDA                    *otherwise its 11 -> branch to ADDA
        
            *AND
ZERO12      BRA     AND

********************ROTATIONS**************************************************
*Code for rotation op code in tree. *AND ADD ADDA ASR LSR ROR ASL LSL ROL 
ROTATION
            BTST    #12,D1                  *check bit #12 again          
            BEQ     ROTATE_VALID            *if 0 we know its not a part 1 tree branch
            BRA     INVALID                 *else it's 1 and that is invalid for rotate op code
 
ROTATE_VALID      
           BTST      #12,D1                 *validating rotation op codes
           BNE       INVALID_S              * if not rotation code, branch to invalid code
           BTST      #8,D1                  * checking direction of rotation
           BNE       GO_LT                  *left rotation op code       
           BRA       GO_RT                  *right rotation op code
GO_LT
           MOVE.W    #1,D7                  * 1 = Left rot
           BRA       CT_ROT
GO_RT   
           MOVE.W    #0,D7                  * 0 = right rot
*********Masking bits for rotation processing,size,and direction determination****       
CT_ROT
            MOVE.W  MB_6_7,D2               *load #6, 7 bits 
            AND.W   D1,D2                   *masking #6, 7 bits
            CMP.W   MB_6_7,D2               *check if bits are 0C000
            BEQ     NM_ROT                  *normal shift if zflag is set to 1
    
            MOVE.W  #5,EA_BIN
            MOVE.W  MB_3_4,D2               *load mask bits #3-4 for ROR
            AND.W   D1,D2                   *mask bits #3-4 ROR
            LSR     #3,D2
            BRA     CMP_ROT                 *branch to compare registries for rotation op type
*****normal rotation*************************************************************        
NM_ROT
            MOVE.W  #1,EA_BIN
            MOVE.W  MB_9_10,D2              *load mask bits #9, 10 0600
            AND.W   D1,D2                   *mask bits #9, 10 0600
            LSR     #8,D2                   *shift bits to get proper #             
            LSR     #1,D2       ***
***function to check what op code is in registry (for processing op)************
CMP_ROT
    CMPI.W  #$0000,D2 ****check if 0 AS op
    BEQ     ASD
    
    CMPI.W  #$0001,D2 ***check if 1, left rot op
    BEQ     LSD

    CMPI.W  #$0003,D2 ****check if 3, righ rot op
    BEQ     ROR

    BRA     INVALID    *otherwise invalid
*-----------------           

****************************************************************
****Processing each opcode after decision find the correct opcode
****************************************************************
**A6 is temp save 
            *NOP
NOP         LEA     N_NOP, A6   *Load string into A6
            BRA     Formatting                          

            *RTS
RTS         LEA     N_RTS, A6
            BRA     Formatting                                      
*-----------MOVEA-------------------------------------
MOVEA       LEA     N_MOVEA, A6
            MOVE.W  #8, EA_BIN
            JSR     Formatting
            
            LEA     F_Period, A6
            JSR     Formatting

            BTST    #13, D1                 *MOVEA don't have Byte size
            BEQ     INVALID                 *if have it, it is invalid
            
            BRA     M_S_Word                          
*-----------MOVE------------------------------------------
MOVE        LEA     N_MOVE, A6
            MOVE.W  #8, EA_BIN             
            JSR     Formatting
            
            LEA     F_Period, A6
            JSR     Formatting
            BRA     M_S_Byte
************Size checking for MOVE & MOVEA function-----------
            *checking #13, 12 bits
M_S_Byte    CLR     D2                      *check size byte
            MOVE.L  D1, D2
            AND.L   #$3000, D2
            CMP.L   #$1000, D2
            BNE     M_S_Word
            MOVE.W  #0,Sz_OP 
            LEA     F_BYTE, A6
            JSR     Formatting
            BRA     Format_Spa
            
M_S_Word    CLR     D2                      
            MOVE.L  D1, D2
            AND.L   #$3000, D2
            CMP.L   #$3000, D2              *check size Word
            BNE     M_S_Long
            MOVE.W  #1,Sz_OP 
            LEA     F_WORD, A6
            JSR     Formatting
            BRA     Format_Spa
                 
M_S_Long    CMP.L   #$2000, D2              *check size Long
            BNE     INVALID
            MOVE.W  #2,Sz_OP     
            LEA     F_LONG, A6
            JSR     Formatting
            BRA     Format_Spa
**************************************************************            
*----------- ADDQ ---------------------------------------------
ADDQ        LEA     N_ADDQ, A6 
            MOVE.W  #6, EA_BIN
            JSR     Formatting 

            LEA     F_Period, A6
            JSR     Formatting
            
            BRA     AN_S_Byte            

*************checking size for ADDQ & NOT function -----------------
*For ADDQ:  00->Byte*
*           01->Word*
*           10->Long*
*For NOT:   00->Byte*
*           01->Word*
*           10->Long*
*--------------------
            *check #7, 6 bit
AN_S_Byte   CLR     D2                      *check size Byte
            MOVE.L  D1, D2
            AND.L   #$00C0, D2              
            CMP.L   #$0000, D2
            BNE     AN_S_Word
            MOVE.W  #0,Sz_OP      
            LEA     F_BYTE, A6
            JSR     Formatting
            BRA     Format_Spa
                        
AN_S_Word   CMP.L   #$0040, D2              *check size Word
            BNE     AN_S_Long 
            MOVE.W  #1,Sz_OP     
            LEA     F_WORD, A6
            JSR     Formatting
            BRA     Format_Spa
            
AN_S_Long   CMP.L   #$0080, D2              *check size Long
            BNE     INVALID   
            MOVE.W  #2,Sz_OP   
            LEA     F_LONG, A6
            JSR     Formatting
            BRA     Format_Spa
************************************************************            
*----------- MOVEQ ------------------------------------------
MOVEQ       LEA     N_MOVEQ, A6             
            MOVE.W  #11, EA_BIN
            JSR     Formatting
            BRA     Format_Spa
            
*-----------NOT ---------------------------------------------
NOT         LEA     N_NOT, A6
            MOVE.W  #1, EA_BIN
            JSR     Formatting
            
            LEA     F_Period, A6
            JSR     Formatting
            
            BRA     AN_S_Byte

*-----------BRA---------------------------------------------
BRA         LEA     N_BRA, A6
            MOVE.W  #3, EA_BIN
            JSR     Formatting
            BRA     Format_Spa

*-----------BEQ ---------------------------------------------
BEQ         LEA     N_BEQ, A6
            MOVE.W  #3, EA_BIN
            JSR     Formatting
            BRA     Format_Spa

*----------- BLE --------------------------------------------
BLE         LEA     N_BLE, A6
            MOVE.W  #3, EA_BIN
            JSR     Formatting
            BRA     Format_Spa

*-----------LEA -------------------------------------------
LEA         LEA     N_LEA, A6
            MOVE.W  #0, EA_BIN
            JSR     Formatting
            BRA     Format_Spa

*----------- BGT -------------------------------------------
BGT         LEA     N_BGT, A6
            MOVE.W  #3, EA_BIN
            JSR     Formatting 
            BRA     Format_Spa
            
*----------- JSR --------------------------------------------
JSR         LEA     N_JSR, A6
            MOVE.W  #1, EA_BIN
            JSR     Formatting
            BRA     Format_Spa
        
*----------- MOVEM ------------------------------------------
MOVEM       LEA     N_MOVEM, A6
            MOVE.W  #7, EA_BIN
            JSR     Formatting
            
            LEA     F_Period, A6
            JSR     Formatting
            
            BRA     MM_S_Word
            
            *checking direction of transfer in ea???
************ MOVEM  Size **********************************
*MOVEM:     0->Word*
*           1->Long*
*------------------*
            *checking #6 bits
MM_S_Word   CLR     D2                      *check size Word
            MOVE.L  D1, D2
            AND.L   #$0040, D2
            CMP.L   #$0000, D2
            BNE     MM_S_Long
            MOVE.W  #0,Sz_OP      
            LEA     F_WORD, A6
            JSR     Formatting
            BRA     Format_Spa
                        
MM_S_Long   CMP.L   #$0040, D2              *check size Long
            BNE     INVALID
            MOVE.W  #2,Sz_OP      
            LEA     F_LONG, A6
            JSR     Formatting
            BRA     Format_Spa
**************************************************************
*----------- OR-----------------------------------------------
OR          MOVE.W  #4,EA_BIN               *load to EA
            LEA     N_OR,A6                 *load the OR string into address A6              
            JSR     Formatting              *write to buffer           
            
            LEA     F_Period, A6            *load period into EA
            JSR     Formatting              *write to buffer           
            
            BRA     AN_S_Byte               *determine size of OR op          
            
*-----------SUB-----------------------------------------------
SUB         MOVE.W  #4,EA_BIN               *load to EA
            LEA     N_SUB,A6                *load the SUB string into address A6                      
            JSR     Formatting              *write to buffer                 
    
            LEA     F_Period, A6
            JSR     Formatting              *write to buffer   
            BRA     AN_S_Byte               *determine size of SUB op  
*-----------AND----------------------------------------------
AND         MOVE.W  #4,EA_BIN               *load to EA
            LEA     N_AND,A6                *load the AND string into address A6      
            JSR     Formatting              *write to buffer    
    
            LEA     F_Period, A6
            JSR     Formatting              *write to buffer    
            BRA     AN_S_Byte               *determine size of AND op  
*-----------ADD-----------------------------------------------
ADD         MOVE.W  #4,EA_BIN               *load to EA
            LEA     N_ADD,A6                *load the ADD string into address A6      
            JSR     Formatting              *write to buffer   
    
            LEA     F_Period, A6
            JSR     Formatting              *write to buffer    
            BRA     AN_S_Byte               *determine size of ADD op  
*-----------ADDA ----------------------------------------------
ADDA        MOVE.W  #0,EA_BIN               *load to EA
            LEA     N_ADDA,A6               *load the ADDA string into address A6  
            JSR     Formatting              *write to buffer   
    
            LEA     F_Period, A6
            JSR     Formatting              *write to buffer   
    
            MOVE.W  D1,D6                   *move copy into d6
            LSR.W   #8,D6                   *move LSD into d6
            JSR     GET_SIZE                *check size with LSD 
    
            JSR     Formatting              *write to buffer   
            BRA     Format_Spa
**************************************************************
*checking size for ADDA*
*011 -> word*
*111 -> long*
*-----------*
            * checking #8, 7, 6 bits
GET_SIZE
            BTST    #0,D6   *check LSD
            BNE     ADDA_LONG *if 1 -> long
            BRA     ADDA_WORD *if 0 -> word

ADDA_WORD   MOVE.W  #1,Sz_OP * set size
            LEA     F_WORD,A6  *load word string             
            RTS 
ADDA_LONG   MOVE.W  #2,Sz_OP * set size
            LEA     F_LONG,A6 *load long string   
            RTS         
*************************************************************************************
*---------------------ROTATIONS for processing the op code-------------------------**    
LSD         *left rotation
            LEA     N_LSR,A6
            BRA     SHIFT_ROT
ASD         *AS rotation
            LEA     N_ASR,A6
            BRA     SHIFT_ROT
ROR         *right rotation
            LEA     N_ROR,A6
            *determining the shift for right
SHIFT_ROT   JSR     SHIFT_SELECT
            JSR     Formatting *write to buffer  
    
            JSR     UTILITY_SIZE *branch to utility function to get size selection
            BRA     Format_Spa *write to buffer  

SHIFT_SELECT
            BTST    #0,D7                   *if 0 its right rotation, 1 is left rotation
            BEQ     RETURN                    *return to shift rot
            ADDA.L  #4,A6                   *otherwise its left, and add one to change version

RETURN    
            RTS 
***************** Get sizes of SIZE LSD RSD ASD*******************************
UTILITY_SIZE
            LEA       F_Period,A6     *load string into address register A6
            JSR       Formatting       *write to buffer  

            JSR       GET_OP_SIZE
            CMPI.W    #-5,Sz_OP      *check if size of bits = 11
            BEQ       NO_SZ_ROT       *if so, branch to no size shift
            JSR       Formatting       *else, write to buffer  
            RTS

            * functions for helping when rotation is no size (memory shifts)
NO_SZ_ROT   MOVE.B    F_Space,-(A2) * remove '.' from the buffer 
            MOVE.W    #2,Sz_OP       * Tell EA to get long from immediate
            RTS
*----------------^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^---------------------*

*******************************************************************************
******************** Function for general size of op code*************************************
GET_OP_SIZE
           MOVE.W    MB_6_7,D2      *mask the bits
           AND.W     D1,D2          *check bits and set flag        
           CMP.W     SB_00,D2       *if the size of bits = 00, its a byte
           BEQ       OP_BYTE        *byte        

           CMP.W     SB_40,D2       *if the size of bits = 01, its a word
           BEQ       OP_WORD        *word        

           CMP.W     SB_80,D2       *if the size of bits = 10, its a long
           BEQ       OP_LONG        *long        
*******invalid code if we get here***************
SIZE_INVLD 
           MOVE.W    #-5,Sz_OP     *11
           RTS

OP_BYTE    
           MOVE.W    #0,Sz_OP      *load flag
           LEA       F_BYTE,A6     *load string
           RTS
OP_WORD    
           MOVE.W    #1,Sz_OP      *load flag
           LEA       F_WORD,A6     *load string
           RTS
OP_LONG    
           MOVE.W    #2,Sz_OP       *load flag
           LEA       F_LONG,A6      *load string
           RTS
  
**************************************************************
**************************************************************
**** Formating the opcode:(Prepare back to I/O)***************
**************************************************************
Formatting  CMPI.B  #0, (A6)                *confirm if (A6)is null or not
            BEQ     F_Done
            MOVE.B  (A6)+, (A2)+            *move all information to A2
            BRA     Formatting

F_Done      RTS
*---------- Space --------------------------------------------
Format_Spa  LEA     F_Space, A6
            MOVE.L  OP_str_Star,D0   * Load opcode string starting address into D0
            SUB.L   A2,D0           * Load  more space into D0
            ADD.W   #$A,D0                  
            
            *making space align 
LOOP_Spa    MOVE.B  (A6),(A2)+
            SUB.B   #1, D0
            CMP.B   #-1, D0                        
            BNE     LOOP_Spa               
            BRA     Laststep                       
************Prepare to EA ****************************************
            *clear all register
Laststep    CLR.L     D3
            MOVE.W    D1,D3                 *move orig code to D3
            JSR       Clearregs
            MOVE.W    EA_BIN,D7
            MOVE.W    Sz_OP ,D4
            MOVE.W    #0,D0
            JSR       EA_PART               *Load to EA
***********Prepare back to I/O*********************************
            *clear all the register 
            MOVE.L     #0,D3
Clearregs   MOVE.L     #0,D1
            MOVE.L     #0,D2
            MOVE.L     #0,D4
            MOVE.L     #0,D5
            MOVE.L     #0,D6
            MOVE.L     #0,D7
            MOVEA.L    #0,A1
            MOVEA.L    #0,A3
            MOVEA.L    #0,A4
            MOVEA.L    #0,A5
            MOVEA.L    #0,A6
            RTS
****************************************************************
***********Invalid opcode **************************************
INVALID     MOVE.L  #1,D0           * Load Bad flag for invalid input
            RTS     *Return to I/O

****************************************************************
***********Invalid SIZE **************************************
INVALID_S  
            MOVE.W  #-5, Sz_OP              *set size bad flag for invalid size
            RTS     *Return to I/O

****************************************************************
****Opcode variables *******************************************
****************************************************************
*--------  Processing variable -------------------------------
OP_str_Star DC.L    $0, 0                    *save starting string A2
Sz_OP       DC.W    $0, 0                    *size
EA_BIN      DC.B    -1, 0                    *storing EA flag
 

*-------- Opcode names----------------------------------------
N_MOVEA     DC.B    'MOVEA', 0
N_MOVE      DC.B    'MOVE', 0
N_NOT       DC.B    'NOT', 0
N_NOP       DC.B    'NOP', 0
N_RTS       DC.B    'RTS', 0
N_JSR       DC.B    'JSR', 0
N_MOVEM     DC.B    'MOVEM', 0
N_LEA       DC.B    'LEA', 0
N_ADDQ      DC.B    'ADDQ', 0
N_BRA       DC.B    'BRA', 0
N_BEQ       DC.B    'BEQ', 0
N_BGT       DC.B    'BGT', 0
N_BLE       DC.B    'BLE', 0
N_MOVEQ     DC.B    'MOVEQ', 0

N_OR      DC.B        'OR',0
N_SUB     DC.B        'SUB',0
N_AND     DC.B        'AND',0
N_ADD     DC.B        'ADD',0
N_ADDA    DC.B        'ADDA',0
N_LSR     DC.B        'LSR',0
N_LSL     DC.B        'LSL',0
N_ASR     DC.B        'ASR',0
N_ASL     DC.B        'ASL',0
N_ROR     DC.B        'ROR',0
N_ROL     DC.B        'ROL',0

*-------- format ----------------------------------------------
F_Period    DC.B    '.', 0
F_BYTE      DC.B    'B', 0
F_WORD      DC.B    'W', 0
F_LONG      DC.B    'L', 0
F_Space     DC.B    '   ', 0


*-------- Constant Opcode-----------------------------------------
*NOP, RTS have a constant machine code
*below are NOT, RTS machine code in Hex format for helping identify NOT, RTS
Hex_NOP     DC.W    $4E71, 0
Hex_RTS     DC.W    $4E75, 0

*--------------------** MASKS ------------------------------------               
* Mask is helping when using AND to check the machine code 
* Mask_X_Y  means bits from X to Y

*using in decision tree 
MASK_12_15 DC.W      $F000           
MASK_8_11  DC.W      $0F00           
MASK_6_8   DC.W      $01C0           
MASK_6_7   DC.W      $00C0           

**const variables for loading and masking bits as well as checking for fixed sizes*********
*decision tree              
MB_12_15 DC.W      $F000           
MB_8_11  DC.W      $0F00           
MB_6_8   DC.W      $01C0           
MB_6_7   DC.W      $00C0           
MB_3_4   DC.W      $0018
MB_9_10  DC.W      $0600
*op processing
SB_00    DC.W      $0000
SB_40    DC.W      $0040
SB_80    DC.W      $0080
****************************************************************
*-----------------------------------------------------------
* Title      : EA PART
* Written by : ARAM ANTONYAN
* Date       : 11/5/2021
* Description: STORE EA TO BUFFER
*-----------------------------------------------------------
***************************************************************
**************EVERYTHING BELLOW IS HELPER FUNCTION ************
***************************************************************
SHIFTING:                       *SHIFT 8 BITS
   LSR.W #$4, D3
   LSR.W #$5, D3
   RTS
BITMASK_LAST3:                  *BITMASK TO CHECK LASTR 
   MOVE.W #%0000000000000111, D5
   AND.W D5,D3
   RTS
FILLOUT:                         *BRANCH THAT WRITES TO BUFFER
   CMPI.B #0,(A6)
   BEQ RET
   MOVE.B (A6)+,(A2)+
   BRA FILLOUT
COUNT_REGISTER:                  *BRANCH THAT COUNTS REGISTER
   MOVE.W #%0000000000000111,D5  *BITMASK
   AND.W D3,D5                   *USING BITMASK
   MOVEA.W D5,A5                 *MOVING ADDRESS TO A5
   JSR A5_CONVERT                *CONVERTING
   RTS
WORD:                            *PREPARE WORD FOR PROCESSING 
   MOVE.W (A0)+, D1
   MOVE.W #%0000000000001111, D5
   MOVE.W #4, D7
   MOVE.W #0, D6                 *VARIABLE TO COUNT LEADING ZEROS AND GET RID OF THEM
LOOP_W:                          
   CMP.W #4, D6                  *COMPARE IF D6 REACHED THE BYTE SIZE OF WORD
   BEQ FILLOUT_WORD              *PUT 0000 IN BUFFER
   CMP.W #4, D6                  
   BEQ RET                       *AND RETURN TO SUBROUTINE 
   ADD.B #1, D6
   ROL.W #4, D1                  *GETTING RID OF LEADING ZEROS
   MOVE.L D1, D2
   AND.W D5, D2                  
   CMP.W #0, D2                  *COMPARE IF ITS 0
   BEQ LOOP_W
   SUB.W D6, D7
   ROR.W #4, D1
LOOP_WW:                         *WRITE A WORD WITHOUT LEADING ZEROS
   ROL.W #4, D1
   MOVE.W D1, D2
   AND.W D5, D2
   MOVEA.W D2, A6
   JSR A6_CONVERT
   DBF D7, LOOP_WW               *LOOP UNTIL D7 WILL BE -1
   RTS
FILLOUT_WORD:
   LEA WORDS, A6
   JSR FILLOUT
   RTS
LONG:                           *THE SAME LIKE FOR WORD BUT FOR LONG WITH VARIABLES 8 AND 0
   MOVE.L (A0)+, D1
   MOVE.W #%0000000000001111, D5
   MOVE.W #8, D7
   MOVE.W #0, D6
LOOP_L:                         *LOOP TO GET RID OF LEADING ZEROS
   CMP.W #8, D6
   BEQ FILLOUT_LONG
   CMP.W #8, D6
   BEQ RET
   ADD.B #1, D6
   ROL.L #4, D1
   MOVE.L D1, D2
   AND.W D5, D2
   CMP.W #0, D2
   BEQ LOOP_L
   SUB.W D6, D7
   ROR.L #4, D1
LOOP_LL:                        *LOOP TO WRITE TO BUFFER WITHOUT ZEROS
   ROL.L #4, D1
   MOVE.L D1, D2
   AND.W D5, D2
   MOVEA.W D2, A6
   JSR A6_CONVERT
   DBF D7, LOOP_LL
   RTS
FILLOUT_LONG:
   LEA LONGS, A6
   JSR FILLOUT
   RTS
BYTE:                           *LOOP FOR WRITING A BYTE TO THE BUFFER
   MOVE.W #%0000000000001111, D5
   MOVE.W #1, D7
LOOP_B:                         *SAME LOGIC LIKE FOR WORD AND LONG
   ROL.B #4, D3
   MOVE.B D3, D2
   AND.W D5, D2
   MOVEA.W D2, A6
   JSR A6_CONVERT
   DBF D7, LOOP_B
   RTS
FILLOUT_BYTE:
   LEA BYTES, A6
   JSR FILLOUT
   RTS
RET:
    RTS   
A6_CONVERT:                     *CONVERTING BRANCHES
    MOVE.B (CONVERTING, A6),(A2)+
    RTS
A5_CONVERT:
    MOVE.B (CONVERTING,A5),(A2)+
    RTS
ROTATION_LOOP1:                 *TWO CASES FOR ROTATION
    JSR SUBQ_EA
    RTS
ROTATION_LOOP2:                 
    JSR SHIFTING
    JSR M000 
    MOVE.W D6,D3
    LEA COMMA,A6
    JSR FILLOUT
    JSR M000
    RTS
SUBQ_EA_HELPER:                 *HELPER FOR SUBQ BRANCH
   JSR SHIFTING
   JSR COUNT_REGISTER
   LEA COMMA, A6
   JSR FILLOUT
   MOVE.W D7,D3
   JSR MODE
   RTS 

MODE:                           *MODE TEST DECISION TREE
   MOVE.B #5, D7                *START FROM BIT 5
   BTST D7, D3                  *BIT CHECK
   BNE M1
   BRA M0
***************************************************************
**************EVERYTHING BELLOW IS MODE DECISION TREE**********
***************************************************************
M1:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M10
   BRA M11
M0:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M00
   BRA M01
M00:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M000
   BRA M001
M01:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M010
   BRA M011
M10:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M100
   BRA M101
M11:
   SUB.B #1, D7
   BTST D7, D3
   BEQ M110
   BRA M111
M000:
   LEA DN, A6
   JSR FILLOUT
   JSR COUNT_REGISTER
   RTS
M001:
   LEA AN, A6
   JSR FILLOUT
   JSR COUNT_REGISTER
   RTS
M101:                           *INVALID
   MOVE.B #1, D0
   RTS
M010:
   LEA AN_B, A6
   JSR FILLOUT
   JSR COUNT_REGISTER
   LEA CLOSE, A6
   JSR FILLOUT
   RTS
M011:
   LEA AN_B, A6
   JSR FILLOUT
   JSR COUNT_REGISTER
   LEA PLUS_AN, A6
   JSR FILLOUT
   RTS 
M100:
   LEA MINUS_AN, A6
   JSR FILLOUT
   JSR COUNT_REGISTER
   LEA CLOSE, A6
   JSR FILLOUT
   RTS
M111:
   SUB.B #1, D7
   BTST D7, D3
   BEQ R0
   BRA R100
   
M110:                           *INVALID
   MOVE.B #1, D0
   RTS
***************************************************************
**************EVERYTHING BELLOW IS REGISTER DECISION TREE******
***************************************************************
R100:
   LEA HASHTAG, A6              *PUT # TO BUFFER
   JSR FILLOUT
   LEA DOLLAR_S, A6             *PUT $ TO BUFFER
   JSR FILLOUT
   CMP.B #2, D4                 *COMPARE A BYTE
   BEQ LONG                     *BRANCH TO LONG
   BRA WORD                     *BRANCH TO WORD
   RTS
R0:
    SUB.B #1, D7
    BTST D7, D3
    BEQ R00
    BRA R01 
R00:
    SUB.B #1, D7
    BTST D7, D3
    BEQ R000
    BRA R001
R01:
    SUB.B #1, D7
    BTST D7, D3
    BEQ R010
    BRA R011  
R011:
    MOVE.B #1, D0
    RTS
R010:
    MOVE.B #1, D0
    RTS
R001:
    LEA DOLLAR_S, A6
    JSR FILLOUT
    JSR LONG
    RTS
R000:
    LEA DOLLAR_S, A6
    JSR FILLOUT
    JSR WORD
    RTS


EA_PART:                        *COMPARING FLAG AND BRANCHING
   CMP #0, D7
   BEQ LEA_ADDA
   CMP #1, D7
   BEQ EA9
   CMP #3, D7
   BEQ DISPACEMENT_EA
   CMP #4, D7
   BEQ DIRECTION
   CMP #5, D7
   BEQ ROTATION_EA
   CMP #6, D7
   BEQ SUBQ_EA
   CMP #7, D7
   BEQ INCOMPLETE_MOVEM
   CMP #8, D7
   BEQ EA12
   CMP #11, D7
   BEQ MOVEQ_EA
   MOVE.W #2, D0
   RTS

EA9:                            *EA WITH 9 BITS
   JSR MODE
   RTS 
MOVEQ_EA:                       *BRANCH FOR MOVEQ
   LEA HASHTAG, A6              *PUT #$ TO BUFFER
   JSR FILLOUT
   LEA DOLLAR_S, A6
   JSR FILLOUT
   JSR BYTE                     *PROCESSING THE BYTE
   LEA COMMA, A6                *ADDING COMMA TO BUFFER
   JSR FILLOUT                  
   LEA DN, A6                   *ADDING DN
   JSR FILLOUT
   JSR SHIFTING                 *SHIFTING, BITMASKING, AND ADDING COUNT REGISTER
   JSR BITMASK_LAST3
   JSR COUNT_REGISTER
   RTS
INCOMPLETE_MOVEM:               *BRANCH FOR INCOMLETE MOVEM
   LEA INC, A6
   JSR FILLOUT
   RTS   
EA12:                           *BRANCH FOR EA 12 BITS
   JSR MODE                     *CHECKING THE MODE FOR DESTINATION
   LEA COMMA, A6                *UPLOADING COMMA
   JSR FILLOUT                  
   MOVE.W D3, D6
   JSR SHIFTING                 *SHIFTING, BITMASKING
   JSR BITMASK_LAST3
   LSR.W #%0011, D6
   MOVE.W #%0000000000111000, D5
   AND.W D5, D6
   ADD.W D6, D3
   JSR MODE                     *CHECKING THE MODE FOR SOURCE
   RTS  


DIRECTION:                      *BRANCH FOR BLE BGT BEQ
   BTST #8,D3                   *CHECK BIT 8
   BEQ EA9_TO_DN                *GOING BRANCH UP IF BIT 8 IS ONE
   MOVE.W D3, D7
   LEA DN, A6                   *PUT DN IN BUFFER
   JSR FILLOUT
   JSR SHIFTING                 *SHFTING 8 BITS
   JSR COUNT_REGISTER           *COUNTING THE REGISTER
   LEA COMMA, A6
   JSR FILLOUT
   MOVE.W D7, D3
   JSR MODE                     *CHECKING OUT THE SOURCE
   RTS 
   
EA9_TO_DN:                      *DN AS A SOURCE
   JSR MODE
   LEA COMMA, A6                *COMMA TO BUFFER
   JSR FILLOUT
   LEA DN, A6                   *D TO BUFFER
   JSR FILLOUT
   JSR SHIFTING
   JSR BITMASK_LAST3            *SHIFTING AND BITMASKING
   JSR COUNT_REGISTER           *FINDING OUT THE REGISTER NUMBER
   RTS  
   
   
DISPACEMENT_EA:                 *BRANCH FOR DISPLACEMENT
   LEA DOLLAR_S, A6             *PUT DOLLAR SIGN IN BUFFER
   JSR FILLOUT
   CMP.B #%00000000,D3          
   BEQ WORD                     *BRANCH TO PROCESS THE WORD
   CMP.B #%11111111,D3
   BEQ LONG                     *BRANCH TO PROCESS THE LONG
   MOVE.W #%0000000011111111, D1 
   AND.W D3,D1
   MOVE.W #%0000000000001111,D5
   MOVE.W #3,D7                 *COUNT 3 BITS
   JSR LOOP_W                   *PROCESS TO WORLD LOOP                 
   RTS
   
   
SUBQ_EA:                        *BRANCH FOR SUBQ
   MOVE.W D3,D7
   LEA HASHTAG,A6               *ADD #
   JSR FILLOUT
   MOVE.W #%0000111000000000,D5 *BITMASK
   AND.W D5,D3
   CMP.W #0,D3
   BNE SUBQ_EA_HELPER
   MOVE.B #%00111000,(A2)+
   LEA COMMA,A6
   JSR FILLOUT
   MOVE.W D7,D3
   JSR MODE                     *CHECK MODE AND REGISTER FURTHER
   RTS      

ROTATION_EA:                    *BRANCH FOR ROTATION
   MOVE.W D3,D6
   AND.W #%1111111111000111,D3  *BITMASK BITS 
   BTST #5,D6                   *BRANCH BASED ON RESULT
   BEQ ROTATION_LOOP1           *IMMEDIATE
   BNE ROTATION_LOOP2           *DATA REG

      
LEA_ADDA:                       *BRANCH FOR LEA AND ADDA
   JSR MODE                     *CHECK MODE AND REG THEN
   LEA COMMA, A6
   JSR FILLOUT
   LEA AN, A6                   *PUT A IN BUFFER
   JSR FILLOUT
   JSR SHIFTING
   JSR BITMASK_LAST3            *BITMASK
   JSR COUNT_REGISTER           *COUNT REGISTER FOR A
   RTS
   

* Put variables and constants here
CONVERTING DC.B '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
           
HASHTAG DC.B '#', 0
DOLLAR_S DC.B '$', 0
DN DC.B 'D', 0
AN DC.B 'A', 0
AN_B DC.B '(A', 0
MINUS_AN DC.B '-(A', 0
CLOSE DC.B ')', 0
PLUS_AN DC.B ')+', 0
COMMA DC.B ',', 0
INC DC.B 'INCOMPLETE NEXT COUPLE LINES MIGHT BE AFFECTED', 0
LONGS DC.B '00000000', 0
BYTES DC.B '00', 0
WORDS DC.B '0000', 0
VARIABLE DC.B '', 0
      END    START        ; last line of source


                    END     START                   ; Last line of source












*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
