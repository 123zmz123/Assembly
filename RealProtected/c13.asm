         ;代码清单13-3
         ;文件名：c13.asm
         ;文件说明：用户程序 
         ;创建日期：2011-10-30 15:19   
         
;===============================================================================
SECTION header vstart=0
;此处的#0x00是汇编地址
         program_length   dd program_end          ;程序总长度#0x00
         
         head_len         dd header_end           ;程序头部的长度#0x04,内核安装完用户头部段的描述符后,将该段的选择子写回到用户程序头部
;内核不要求用户程序提供栈空间,而改成由内核动态分配,以减轻用户程序编写的负担,当内核分配了栈空间之后,会把栈段的选择子填写到这里,用户程序开始执行时,可以从这里取得选择子以初始化自己的栈
         stack_seg        dd 0                    ;用于接收堆栈段选择子#0x08
         stack_len        dd 1                    ;程序建议的堆栈大小#0x0c,即用户程序编写者建议的栈大小
                                                  ;以4KB为单位,如果是1就是希望分配4KB的空间,2是8KB,以此类推
                                                  
         prgentry         dd start                ;程序入口#0x10,用户程序入口点的32位偏移地址
         code_seg         dd section.code.start   ;代码段位置#0x14,用户程序代码段的起始汇编地址,当内核完成对用户程序的加载和重定位后,将把该段的选择子回填到这里,仅占用低字部分,这样一来,它和0x10处的双字一起,共同组成一个6字节的入口点,内核从这里转移控制到用户程序
         code_len         dd code_end             ;用户程序代码段长度,以字节为单位#0x18

         data_seg         dd section.data.start   ;数据段位置#0x1c,是用户程序数据段的起始汇编地址,当内核完成用户程序的加载和重定位后,将把该段的选择子回填到这里,仅占用低字部分
         data_len         dd data_end             ;用户程序数据段长度#0x20,以字节为单位
             
;-------------------------------------------------------------------------------
         ;符号地址检索表(Symbol-Address Lookup Table,SALT作者自己建立的,不是标准)
         salt_items       dd (header_end-salt)/256 ;#0x24,用于初始化表的项数,也就是符号名的数量,用表格总长度除以256得到
         
         salt:                                     ;#0x28
         PrintString      db  '@PrintString'       ;@无特殊意义,仅仅在概念上表示接口
                     times 256-($-PrintString) db 0;先计算出符号名的实际字符数,即$-PrintString,再用256减去实际字符数就得到伪指令DB的重复次数
                     
         TerminateProgram db  '@TerminateProgram'
                     times 256-($-TerminateProgram) db 0
                     
         ReadDiskData     db  '@ReadDiskData'
                     times 256-($-ReadDiskData) db 0
                 
header_end:

;===============================================================================
SECTION data vstart=0    
                         
         buffer times 1024 db  0         ;缓冲区

         message_1         db  0x0d,0x0a,0x0d,0x0a
                           db  '**********User program is runing**********'
                           db  0x0d,0x0a,0
         message_2         db  '  Disk data:',0x0d,0x0a,0

data_end:

;===============================================================================
      [bits 32]
;===============================================================================
SECTION code vstart=0
start:                                       ;内核加载完用户程序跳转到此处执行,此时段寄存器DS是指向头部段的
         mov eax,ds                          ;使段寄存器FS指向头部段,因为后面要调用内核过程,而这些过程都要求使用DS,所以把DS解放出来
         mov fs,eax
;第60~62行,切换到用户程序自己的栈,并初始化ESP=0
         mov eax,[stack_seg]
         mov ss,eax
         mov esp,0
;第64~65行,设置DS到用户程序自己的数据段
         mov eax,[data_seg]
         mov ds,eax
;第67~68行,调用内核过程显示字符串,以表明用户程序正在运行中,该内核过程要求用DS:EBX指向零终止的字符串
         mov ebx,message_1
         call far [fs:PrintString]
;第70~72行,调用内核过程,从硬盘读一个扇区,ReadDiskData过程的内部名称是read_hard_disk_0,所以ReadDiskData需要传入两个参数第二是DS:EBX传入缓冲区的首地址
         mov eax,100                         ;逻辑扇区号100,第一是EAX寄存器传入要读的逻辑扇区号,要读的逻辑扇区号是100
         mov ebx,buffer                      ;缓冲区偏移地址,第二是DS:EBX传入缓冲区的首地址,缓冲区位于用户程序的数据段中,是在第43行用标号buffer声明的,并初始化了1024个字节
         call far [fs:ReadDiskData]          ;段间调用
;第74~78行,先调用内核过程显示一个题头,接着再次调用内核过程显示刚刚从硬盘读出的内容,在做完上述事情后,用户程序的任务也就完成了,第80行,调用内核过程返回内核
         mov ebx,message_2
         call far [fs:PrintString]
     
         mov ebx,buffer 
         call far [fs:PrintString]           ;too.
     
         jmp far [fs:TerminateProgram]       ;将控制权返回到系统,回到内核代码中,在内核中,用户程序的返回点位于第582行
;这确实是一个调用门,而且通过jmp far指令使用调用门也没有任何问题,问题在于,当控制转移到内核时,当前特权级没有变化,还是3,因为使用jmp far指令通过调用门转移控制是不会改变当前特权级别的
code_end:

;===============================================================================
SECTION trail
;-------------------------------------------------------------------------------
program_end:
;以下是注释说明:
;主引导程序构成:
;第一:常数部分
;     1.内核加载的起始内存地址
;     2.内核的起始逻辑扇区号
;第二:设置SS=0x0000 0000,SP=0x7c00
;第三:计算GDT所在的逻辑段地址
;第四:建立保护模式下的描述符
;     1.跳过0号
;     2.创建1#描述符，这是一个数据段，对应0~4GB的线性地址空间
;     3.创建保护模式下初始代码段描述符
;     4.建立保护模式下的堆栈段描述符
;     5.建立保护模式下的显示缓冲区描述符
;第五:初始化描述符表寄存器GDTR,包括界限和基地址
;第六:打开A20
;第七:屏蔽中断
;第八:设置CR0的PE位,进入保护模式    jmp dword 0x0010:flush
;第九:flush:
;     使DS指向全部4GB的内存空间
;     使SS指向初始的栈空间
;第十:加载系统核心程序,此时使用前面定义的常数,内核加载的起始内存地址和内核的起始逻辑扇区号
;     1.读第一个扇区
;     2.判断整个内核有多大
;     3.读取内核的剩余部分
;第十一:标号setup:
;     1.建立核心公用例程段描述符
;     2.建立核心数据段描述符
;     3.建立核心代码段描述符
;     4.修改GDTR
;     5.跳转到内核
;第十二部分:例程
;     1.read_hard_disk_0:从硬盘读取一个逻辑扇区
;     2.make_gdt_descriptor:构造描述符
;第十三部分:标号pgdt
;     1.dw  GDT界限值
;     2.GDT起始物理地址,已定为0x00007e00
;第十四部分:引导程序结尾标志
;
;
;主引导程序的主要任务:
;第零:常数,事先已经声明内核加载的起始地址和内核在硬盘上的起始逻辑扇区号
;第一:初始化实模式下的栈,设置SS=0x0000 0000,SP=0x7c00
;第二:决定将GDT加载在主引导扇区之后,所以要计算GDT所在的逻辑段地址
;第三:建立实模式下的描述符
;     0号空
;     1号,数据段，对应0~4GB的线性地址空间
;     2号,初始代码段描述符,也就是主引导程序所在区域
;     3号,堆栈段描述符,主引导程序下方
;     4号,显示缓冲区描述符
;     建立完lgdt加载GDTR寄存器
;第四:打开A20并屏蔽中断
;第五:设置CR0寄存器以进入保护模式
;第六:加载4GB空间选择子,使DS指向全部4GB的内存空间
;第七:初始化栈空间,清零esp
;第八:读取内核第一扇区
;第九:根据内核头部判断大小并读取剩余扇区
;第十:建立内核公用例程段描述符,使用make_gdt_descriptor
;第十一:建立内核核心数据段描述符,使用make_gdt_descriptor
;第十二:建立内核核心代码段描述符,使用make_gdt_descriptor
;第十三:修改描述符界限值
;第十四:重新lgdt加载GDTR寄存器
;第十五:间接远转移跳转到内核入口点(start标号处)执行
;第十六:进入内核中执行
;内核的执行过程如下:
;第一:加载核心数据段选择子
;第二:显示字符串说明已经进入保护模式,并且内核加载完成
;第三:显示处理器品牌信息,分三次进行
;第四:调用内核代码段中的load_relocate_program,加载并重定位用户程序
;     进入load_relocate_program过程中
;     1.保存现场,加载内核数据段选择子,切换DS到内核数据段,因为用户程序第一个扇区先读到内核数据段中的缓冲区
;     2.读取用户程序第一扇区
;     3.判断用户程序有多大(确切有几个扇区)准备申请内存空间,此处需调用系统公共例程段中的例程read_hard_disk_0
;     3.调用公共例程段中的allocate_memory以分配内存
;           进入allocate_memory过程中
;           1.保存现场,加载内核数据段选择子,使DS指向内核数据段
;           2.内核数据段中已经定义了一个ram_alloc标号,该标号是内存分配的起始地址
;             这一步先把该标号加上此次希望分配的字节数,下次再分配内存将从新的地址开始分配
;           3.检测可用内存数量(略)
;           4.在将新的起始地址写回内核数据段标号ram_alloc处之前4字节对齐,没对齐强制对齐
;           5.恢复load_relocate_program调用allocate_memory过程前的现场并返回,此时ECX保存有分配的起始线性地址
;     回到load_relocate_program过程中此时得到申请得到的内存首地址在ECX中
;     4.此时获得申请到的内存首地址,先从ecx复制到ebx用ebx压栈保存,压栈保存以便以后访问用户程序头部
;     5.将申请到的内存首地址传送到ebx作为起始地址从硬盘上加载整个用户程序
;     6.计算出用户程序有几个512字节,将数量传送到ecx计数寄存器以准备循环读取
;     7.读取用户程序到分配的内存空间后,下一步建立用户程序头部段描述符
;           1.恢复刚才压栈的程序装载首地址到edi
;           2.使用edi获取到用户程序加载的起始线性地址作为头部段的段基地址并传送到eax
;           3.取得用户程序头部段的长度并减去1得到用户头部段的段界限,存放在ebx中
;           4.在ecx中构建段描述符属性
;           5.将上面的EAX,EBX,ECX作为参数调用系统公共例程make_seg_descriptor构建用户程序的头部段描述符
;           6.make_seg_descriptor返回EDX:EAX=描述符,立即调用公共例程段内的set_up_gdt_descriptor过程以安装当前构造完成的头部段描述符
;                 进入set_up_gdt_descriptor过程中
;                 1.压栈保存相关寄存器
;                 2.切换到核心数据段
;                 3.保存GDT信息(基地址和边界)到内核数据段中声明的标号pgdt处以便开始处理GDT,才能知道从哪里开始安装描述符
;                 4.令附加段寄存器es指向全部4GB内存空间以操作全局描述符表
;                 5.安装用户头部段描述符
;                 6.更新内核数据段pgdt标号处保存的GDT信息
;                 7.重新加载GDTR
;                 8.算出新安装的描述符的索引号并生成选择子
;                 9.恢复现场并返回load_relocate_program过程
;           7.安装完用户头部段的描述符后,将该段的选择子写回到用户程序头部
;     8.建立程序代码段描述符并安装,写回段选择子,同上
;     9.建立程序数据段描述符并安装,写回段选择子,同上
;     10.建立程序堆栈段描述符
;           1.从用户程序头部取得建议栈大小(倍率)
;           2.获得栈段描述符的段界限
;           3.获得栈段的字节大小
;           4.调用allocate_memory分配栈段内存
;           5.因为栈段向下扩展,将allocate_memory返回的内存低端地址加上栈大小获得栈的高端地址,作为栈段基地址
;           6.创建栈段描述符
;           7.安装栈段描述符到GDT
;           8.将栈段选择子写回到用户程序头部,供用户程序在接管处理器控制权之后使用
;     11.重定位用户程序内的符号地址
;           1.取出用户头部段选择子,令ES指向用户程序头部
;           2.令DS指向内核数据段,因为C-SALT位于内核数据段内
;           3.清标志寄存器的方向标志,使cmps按正向比较
;           4.双层循环前的准备工作,安排用户程序的SALT条目数到ECX,另EDI=第一个用户SALT的表项在用户头部段的偏移量0x28
;           5.进入外循环
;                 1.压栈ECX(用户程序的SALT条目数)和EDI(第一个用户SALT的表项在用户头部段的偏移量0x28)
;                 2.进入内循环
;                       1.令ECX=C-SALT的条目数,因为要从内核SALT的第一个开始比较起,总共要比较ECX次
;                       2.令ESI=内核SALT表头地址
;                       3.将比较过程要破坏的寄存器压栈,EDI(第一个用户SALT的表项在用户头部段的偏移量0x28),ESI(内核SALT表头地址),ECX(C-SALT的条目数)
;                       4.将每个条目的比较次数64传入ECX
;                       5.重复比较,该操作将会同时改变DS:ESI和ES:EDI
;                       6.若相等则比较完时,DS:ESI将指向C-SALT表项的最后6字节地址信息,ES:EDI指向此次比较的用户SALT表项的末尾
;                       7.将匹配的C-SALT表项的最后6字节地址信息回填到用户U-SALT的符号名处,供用户程序使用
;                       8.弹出上次压栈的ECX(内核SALT的条目数),ESI(内核SALT表头地址),EDI(用户程序的SALT第一个表项在头部段的偏移量)
;                       9.ESI(内核SALT表头地址)加上每个C-SALT表项的长度指向下一个内核SALT表项准备下一次比较(因为如果第一次就匹配了,后面就不可能在匹配这个内核SALT表项,但是还是往下比较,看看后面还有没有"更"匹配的,所以才加上内核SALT表项的长度)刚开始还以为会不会是个漏洞啊,不会
;                       10.loop指令令ECX=C-SALT的条目数-1,跳转到内循环,再往下比较,知道和所有的内核SALT表项比较完
;                       11.弹出EDI=用户程序的SALT第一个表项在头部段的偏移量,然后加上256指向U-SALT下一个条目,此时上一个用户符号名已经匹配完
;                       12.弹出外循环次数ECX=用户程序的SALT条目数
;                       13.loop指令令ECX=U-SALT的条目数-1,并跳到外循环,此时EDI已经是下一个要比较的U-SALT表项在用户程序头部段的偏移量了
;           6.重定位用户程序内的符号地址完成
;     12.把用户程序头部段的选择子传送到AX寄存器,AX寄存器中的选择子是作为参数返回到主程序的,主程序将用它来找到用户程序的入口,并从那里进入
;     13.恢复调用load_relocate_program前的现场
;第五:显示信息表明加载并重定位用户程序已完成
;第六:保存当前内核的堆栈指针到内核数据段esp_pointer标号处
;第七:用刚才加载并重定位用户程序后返回在ax中的用户程序头部段选择子来切换ds指向用户程序头部段
;第八:用户程序头部保存有用户程序入口点,此时ds指向用户程序头部段,执行一个间接远转移,控制权交给用户程序（入口点）进入用户程序内接着执行
;第九:执行用户程序
;     1.跳转到用户程序入口点,用户程序代码段标号start处
;     2.使段寄存器FS指向头部段,因为后面要调用内核过程,而这些过程都要求使用DS,所以把DS解放出来
;     3.切换到用户程序自己的栈,并初始化ESP=0,此时头部已经有由内核加载用户程序时分配的栈段的选择子,是内核加载用户程序时回填的
;     4.设置DS到用户程序自己的数据段,此时头部已经有由内核加载用户程序时回填的用户数据段选择子
;     5.调用内核过程显示自己数据段中的字符串
;     6.调用内核过程,从硬盘读一个扇区到自己数据段中的缓冲区,ReadDiskData过程的内部名称是read_hard_disk_0
;     7.再次调用内核过程显示自己数据段中的字符串
;     8.再次调用内核过程显示刚刚从硬盘读出的内容
;     9.调用内核过程返回内核
;第十:回到内核
;     1.切换ds回自己的核心数据段
;     2.切换回自己的堆栈,使栈段寄存器SS重新指向内核栈段,并从内核数据段中取得和恢复原先的栈指针位置
;     3.显示一条消息,表示现在已经回到内核
;     4.回收前一个用户程序所占用的内存,并启动下一个用户程序,但是现在我们无事可做
;     5.使处理器进入停机状态,别忘了在进入保护模式之前,我们用 cli指令关闭了中断,所以除非由NMI产生,处理器将一直处于停机状态
;
;
;
;内核构成:
;第一:段选择子常量部分,不占用空间
;     1.内核代码段选择子,equ伪指令声明的数值不占用空间
;     2.内核数据段选择子 
;     3.系统公共例程代码段的选择子 
;     4.视频显示缓冲区的段选择子
;     5.内核堆栈段选择子
;     6.整个0-4GB内存的段的选择子
;第二:内核头部,记录了各个段的汇编位置,供加载时定位内核的各个部分,也就是告诉初始化代码如何加载内核
;     1.核心程序总长度
;     2.系统公用例程段的起始汇编地址
;     3.核心数据段的起始汇编地址
;     4.核心代码段的起始汇编地址
;     5.核心代码段入口点
;           1.段内偏移
;           2.内核代码段选择子(前面声明过的)
;第三:系统公共例程代码段
;     put_string:字符串显示例程
;     put_char:在当前光标处显示一个字符,并推进
;     read_hard_disk_0:从硬盘读取一个逻辑扇区
;     put_hex_dword:在当前光标处以十六进制形式显示一个双字并推进光标
;     allocate_memory:分配内存
;     set_up_gdt_descriptor:在GDT内安装一个新的描述符
;     make_seg_descriptor:构造存储器和系统的段描述符
;第四:系统核心的数据段
;     1.pgdt用于保存GDT信息
;     2.ram_alloc用于记录下次分配内存时的起始地址
;     ...
;第五:内核代码段
;     1.load_relocate_program:加载并重定位用户程序
;     2.start:c13_mbr.asm主引导程序执行完跳转到此处,这里是内核入口
;     3.return_point:用户程序返回点
;     4.hlt停机
;
;用户程序构成:
;第一:用户程序头部
;     1.程序总长度
;     2.程序头部长度,内核安装完用户头部段的描述符后,将头部段的选择子写回到此处
;     3.接收堆栈段选择子的回填坑,原内容0
;     4.堆栈段建议大小1
;     5.用户程序入口点的32位偏移地址
;     6.接收代码段选择子的回填坑,原内容section.code.start
;     7.用户程序代码段长度
;     8.接收数据段选择子的回填坑,原内容section.data.start 
;     9.用户程序数据段长度
;     10.符号地址检索表
;           1.表项数
;           2.PrintString
;           3.TerminateProgram
;           4.ReadDiskData
;第二:数据段
;     1.1024字节的缓冲区
;     2.message_1
;     3.message_2
;第三:代码段
;     1.start:标号,用户程序入口点
;     2.切换到用户程序自己的栈,并初始化ESP=0
;     3.设置DS到用户程序自己的数据段
;     4.调用内核过程显示字符串
;     5.调用内核过程,从硬盘读一个扇区
;     6.显示读到的数据
;     7.返回内核
;第四:用户程序尾部