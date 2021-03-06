         ;代码清单9-2
         ;文件名：c09_2.asm
         ;文件说明：用于演示BIOS中断的用户程序,写入逻辑100扇区,回车键仅仅是将光标移回行首,退格键仅仅是将光标退后,并不破坏该位置的字符
         ;创建日期：2012-3-28 20:35
         
;===============================================================================
SECTION header vstart=0                     ;定义用户程序头部段 
    program_length  dd program_end          ;程序总长度[0x00]
    
    ;用户程序入口点
    code_entry      dw start                ;偏移地址[0x04]
                    dd section.code.start   ;段地址[0x06] 
    
    realloc_tbl_len dw (header_end-realloc_begin)/4
                                            ;段重定位表项个数[0x0a]
    
    realloc_begin:
    ;段重定位表           
    code_segment    dd section.code.start   ;[0x0c]
    data_segment    dd section.data.start   ;[0x14]
    stack_segment   dd section.stack.start  ;[0x1c]
    
header_end:                
    
;===============================================================================
SECTION code align=16 vstart=0           ;定义代码段（16字节对齐） 
start:
      mov ax,[stack_segment]             ;初始化各个段寄存器
      mov ss,ax
      mov sp,ss_pointer
      mov ax,[data_segment]
      mov ds,ax
      
      mov cx,msg_end-message             ;使用循环方法在屏幕上显示字符串,cx循环次数
      mov bx,message                     ;bx取得字符串首地址
      
 .putc:
      mov ah,0x0e                        ;使用BIOS中断,具体是中断0x10的0x0e号功能
      mov al,[bx]                        ;该功能用于在屏幕上的光标位置处写一个字符,并推进光标位置
      int 0x10
      inc bx                             ;递增BX中的偏移地址,指向下一个字符在数据段中的位置,然后loop指令及那个CX减去1,不为零的情况下返回循环体的最开始,继续显示下一个字符
      loop .putc

 .reps:
      mov ah,0x00                        ;在寄存器AH指定0x00号功能,使用软中断0x16从键盘读取字符,
      int 0x16                           ;该中断返回后,寄存器AL中位字符的ASCII码
      
      mov ah,0x0e                        ;又一次使用中断0x10的0x0e号功能,把从键盘取得的字符显示在屏幕上
      mov bl,0x07
      int 0x10

      jmp .reps                          ;无条件转移,重新从键盘读取新的字符并显示

;===============================================================================
SECTION data align=16 vstart=0

    message       db 'Hello, friend!',0x0d,0x0a
                  db 'This simple procedure used to demonstrate '
                  db 'the BIOS interrupt.',0x0d,0x0a
                  db 'Please press the keys on the keyboard ->'
    msg_end:
                   
;===============================================================================
SECTION stack align=16 vstart=0
           
                 resb 256
ss_pointer:
 
;===============================================================================
SECTION program_trail
program_end:
;说明注释:
;内部中断:
;和硬件中断不同,内部中断发生在处理器内部,由执行的指令引起的,比如检测到div或idiv指令的除数为0,或者除法结果溢出,将产生0号中断(除法错中断)
;处理器遇到非法指令时,产生中断6,非法指令是指指令的操作码没有定义或者指令超过规定长度,通常意味着那不是一条指令,而是普通的数
;内部中断不受标志位IF的影响,也不需要中断识别总线周期,它们的中断类型固定,可以立即转入相应的处理过程
;软中断:
;软中断是由int指令引起的中断处理,也不需要中断识别总线周期,中断号在指令中给出
;   int3    断点中断指令,机器码CC,单字节指令,当程序运行不正常时,可以在调试时使用
;   int 3   int3和int 3不是一回事,前者机器码CC,后者CD 03,第二个字节给出中断号
;   int imm8
;   into    溢出中断指令,机器码CE,单字节指令,当处理器执行到这条指令时,如果标志位OF=1,那么产生4号中断,否则什么也不做
;指令都是连续存放的,所谓断点就是某条指令的起始地址,int3是单字节指令,这是有意设计的,当需要设置断点时,可以将断点处那条指令的第一个字节改成0xcc,原字节保留
;当处理器执行到int3时,即发生3号中断,转去执行相应的中断处理程序,中断处理程序的执行也要用到各个寄存器,这会破坏它们的内容,但push指令不会,可以在该程序内先压栈所有相关寄存器和内存单元
;然后分别取出予以显示,这就是中断前的现场内容,最后再恢复那条指令的第一个字节,并修改位于栈中的返回地址,执行iret指令
;BIOS中断:
;可以为所有的中断类型自定义中断处理过程,包括内部中断,硬件中断和软中断,特别是处理器允许256种中断,且大部分都没有被硬件或处理器内部中断占用
;编写自己的中断处理程序有相当大的优越之处,int指令不需要知道目标程序的入口地址,不像jmp和call指令还必须直接或间接给出目标位置的段地址和偏移地址,如果这一切都是自己安排的倒也不成问题,但是如果想调用别人的代码
;比如操作系统的功能,就会很麻烦,比如想读取硬盘上的一个文件,因为操作系统有这样的功能,就不必自己再写一套代码,直接调用操作系统例程就可以了
;但是操作系统通常不会给出或者公布硬盘读写例程的段地址和偏移地址,因为操作系统经常更新修改,例程的入口地址也会发送变化,而且也不能保证每次启动计算机,操作系统总是待在同一个内存位置
;因为有了软中断,每次操作系统加载完自己后,以中断处理程序的形式提供硬盘读写功能,并把该例程的地址填写到中断向量表中,这样用户程序需要该功能时,只需发出一个软中断即可
;最有名的软中断是BIOS中断,又称为BIOS功能调用,BIOS中断是在计算机加电之后,BIOS程序执行期间安装建立起来的,这些中断功能在加载和执行主引导扇区之前就可以使用,即使是BIOS调用,要访问硬件也是通过端口一级的途径
;BIOS可能会为一些简单的外围设备提供初始化代码和功能调用代码,并填写中断向量表,但也有一些BIOS中断是由外部设备接口自己建立的
;键盘服务中断号0x16
;为了区分针对同一硬件的不同功能,使用寄存器AH来指定具体的功能编号,以下指令用来从键盘读取一个按键:
;   mov ah,0x00     ;寄存器AH来指定具体的功能编号,从键盘读字符
;   int 0x16        ;键盘服务,返回时,字符代码在寄存器al中
;当寄存器AH的内容是0x00时,执行int 0x16后,中断服务例程会监视键盘动作,当他返回时,会在寄存器AL中存放键盘的ASCII码
;关于BIOS如何初始化外围设备:
;每个外部设备接口,包括各种板卡,显卡,网卡,键盘接口电路,硬件控制器等,都有自己的只读存储器,类似于BIOS芯片,这些ROM提供了它自己的功能调用例程,以及本设备的初始化代码
;按照规范,前两个单元的内容是0x55和0xAA,第三个单元是本ROM中以512字节为单位的代码长度,从第四个单元开始,就是实际的ROM代码
;其次我们知道从内存物理地址A0000开始到FFFFF结束,有相当一部分空间是留给外围设备使用的,如果设备存在,那么它自带的ROM会映射到分配给他的地址范围内
;在计算机启动期间,BIOS程序会以2KB为单位搜索内存地址C0000~E0000之间的区域,当它发现某个区域的头两个字节是0x55和0xAA时,那意味着该区域有ROM代码存在,是有效的,接着对该区域做累加和检查
;看结果是否与第三单元符合,如果相符,就从第四个单元进入,这时,处理器执行的是硬件自带的程序指令,这些指令初始化外部设备的相关寄存器和工作状态,最后填写中断向量表,使它们指向自带的中断处理过程