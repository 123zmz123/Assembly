         ;代码清单6-1
         ;文件名：c06_mbr.asm
         ;文件说明：硬盘主引导扇区代码
         ;创建日期：2011-4-12 22:12 
      
         jmp near start                ;\续行符,表明下一行与当前行合并为一行
         
  mytext db 'L',0x07,'a',0x07,'b',0x07,'e',0x07,'l',0x07,' ',0x07,'o',0x07,\
            'f',0x07,'f',0x07,'s',0x07,'e',0x07,'t',0x07,':',0x07
  number db 0,0,0,0,0
  
  start:
         mov ax,0x7c0                  ;设置数据段基地址 
         mov ds,ax                     ;将数据段基地址传入ds数据段寄存器
         
         mov ax,0xb800                 ;设置附加段基地址
         mov es,ax                     ;将附加段基地址传入es附加段寄存器
         
         cld                           ;方向标志清零指令cld,无操作数指令,将df清零以表示传送方向为正,与其相反的是std置方向标志指令
         mov si,mytext                 ;设置si寄存器的内容到源串的首地址,也就是mytext处的汇编地址,原始数据串的段地址由ds指定,偏移地址由si指定,简写为ds:si
         mov di,0                      ;设置目的地的首地址到di寄存器,屏幕上第一个字符的位置对应着0xB800段的开始处,所以设置di为0,要传送到的目的地址由es:di指定,每传送一次di加2
         mov cx,(number-mytext)/2      ;设置要批量传送的字节数到cx寄存器,因为数据串是在两个标号number和mytext之间声明的,而标号代表的是汇编地址,所以允许将他们相减并除以2(每个要显示的字符占2字节)来得到,这个阶段是在编译时进行的,而不是在指令执行时,实际上等于 13
         rep movsw                     ;movsw一次传送一个字,rep表示cx不为零则重复执行,因为单纯的movsw只能执行一次
     
         ;得到标号所代表的偏移地址并传到寄存器ax
         mov ax,number
         
         ;计算各个数位
         mov bx,ax                     ;使bx指向该处的偏移地址,等效于mov bx,number用寄存器传递更快更方便
         mov cx,5                      ;将循环次数5传到cx 
         mov si,10                     ;将除数10传到si 
  digit: 
         xor dx,dx                     ;异或dx与dx,作用是将dx清零
         div si                        ;使用32位二进制数除以16位二进制数,8086是16位处理器,无法直接提供32位的被除数,要求被除数的高16位在dx中,低16位在ax中,除完商在ax中,余数在dx中
         mov [bx],dl                   ;将dl中得到的余数传到由bx所指示的内存单元中(在8086处理器上如果要用寄存器来提供偏移地址,只能使用bx/si/di/bp这四个寄存器),保存数位
         inc bx                        ;将bx内容加一指向下一个内存单元
         loop digit                    ;loop指令的功能是重复执行一段代码,在这里将cx减一并判断是否为零,如果不为零则跳转到标号digit所在的位置处执行,此处loop指令的机器指令操作码是0xE2,后面跟一个直接的操作数,也是相对于标号处的偏移量,编译器用标号的汇编地址减去loop指令的汇编地址再减去2得到
                                       ;处理器在执行loop指令指令时候会顺序做两件事:1.将CX寄存器的内容减一;2.如果CX不为0,转移到指定的位置处执行,否则顺序执行后面的指令
         ;显示各个数位
         mov bx,number 
         mov si,4                      
   show:
         mov al,[bx+si]
         add al,0x30
         mov ah,0x04
         mov [es:di],ax
         add di,2
         dec si                        ;将si内容减一
         jns show                      ;该语句意思是如果未设置符号位,则转移到标号show处继续执行,Intel处理器标志寄存器中有符号位SF,很多算数运算会影响到SF,比如这里的dec指令,如果计算结果的最高位为0,则SF=0
                                       ;由于si的初始值为4,第一次执行dec si后,si=3,即二进制0000000000000011,符号位是比特0,SF=0,于是当执行jns show时,符合条件,转移到标号show处执行,当SF=1时条件不满足就执行后面第51行的代码
         mov word [es:di],0x0744

         jmp near $                    ;$等同于标号,隐藏于当前行行首的标号

  times 510-($-$$) db 0                ;出去0x55和0xAA还剩510字节,$是当前行的汇编地址,$$是NASM编译器提供的另一个标记,代表当前汇编节段的起始汇编地址,当前程序没有定义节或段,默认自成一个汇编段,起始的汇编地址是0
                   db 0x55,0xaa
;movsb和movsw指令执行时,原始数据串的段地址由ds指定,偏移地址由si指定,简写为ds:si
;要传送到的目的地址由es:di指定,传送的字节数(movsb)或字(movsw)由cx指定
;除此之外还要指定传送的方向,正向传送是指传送操作的方向是从内存的低地址端到高地址端,反向传送相反
;正向传送时,每传送一个字节或一个字,si和di加上1或加上2
;反向传送时,每传送一个字节或一个字,si和di减去1或减去2
;不管正向还是反向传送,每传送一个字节或一个字,cx自动减去1
