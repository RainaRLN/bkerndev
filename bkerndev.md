## 01-前言

&emsp;&emsp;内核开发不是件容易的事, 这是对一个程序员编程能力的考验。开发内核其实就是开发一个能够与硬件交互和管理硬件的软件。内核也是一个操作系统的核心, 是管理硬件资源的逻辑。

&emsp;&emsp;处理器或是CPU是内核需要管理的最重要的系统资源之一。内核对其的管理体现在: 给特定操作分配时间, 并允许在另一个调度事件发生时中断任务或进程。也就是**多任务处理**(multitasking)。多任务处理的实现方式有: 

- 协作式多任务处理(cooperative multitasking): 当程序自身想要放弃处理下一个可执行进程或任务的时间时, 将调用“yield”函数主动放弃时间片。
- 抢占式多任务处理(preemptive multitasking): 使用系统定时器来中断当前进程切换到新的进程。这种强制切换形式, 更好地保证了进程可以得到一段运行时间。

目前有几种调度算法用于寻找下一个要运行的进程, 其中最简单的是轮循调度(Round Robin), 你只需要在列表中获取下一个进程, 然后选择该进程运行。复杂的调度涉及优先级, 那些优先级高的任务比优先级低的任务允许分派到更多运行时间。更为复杂的是实时调度(Real-time scheduler), 用来保证某个进程至少运行一定数量的定时器时间。实时系统的计算正确性不仅仅取决于计算的逻辑正确性, 还却决于产生结果的时间。如果未满足系统的时间约束, 则认为系统失效, 也可认为没有得到正确的计算结果。

&emsp;&emsp;系统的另一个重要的资源显然是内存(Memory)。有时候内存资源甚至比CPU时间资源更加珍贵, 因为内存是有限的, 而CPU时间确不是。你可以将你的内核设计成内存高效, 但会牺牲大量CPU。你也可以设计成CPU高效, 使用内存存储缓存和缓冲区来记住常用项而不是查找它们。最好的当然是两者兼顾: 争取最佳的内存使用, 同时保留CPU时间。

&emsp;&emsp;还有一个内核需要管理的资源是硬件资源, 包括: 

- 终端请求(IRQ): 键盘、硬盘等硬件设备发送的特殊信号, 用来告诉CPU我已经准备好数据了, 你可以执行某个例程来处理它。
- 直接存储器访问(DMA)通道: DMA通道允许设备锁定存储器总线并在需要的时候将数据直接传输到系统存储器中, 而不停止处理器的执行。支持DMA的设备可以在不打扰CPU的情况下传输数据, 再通过IRQ中断告诉CPU数据传输完完成, 很好地提高了系统的性能。声卡和以太卡就是使用这种方式。
- 寻址: 比如内存其实是I/O总线端口下的一个地址。设备可以使用I/O端口被配置或读写数据。设备可以使用的I/O端口有很多, 通常使用8路或16路I/O。

### 概述

&emsp;&emsp;本教程的旨在向读者展示如何搭建起内核的基础, 包括: 

1. 配置开发环境
2. 基础知识: GRUB引导程序设置
3. 链接到其他文件并调用main()
4. 屏幕输出
5. 设置自定义全局描述符表(GDT)
6. 设置自定义中断描述符表(IDT)
7. 设置中断服务程序(ISR)处理中断和IRQs
8. 重映射可编程中断控制器(PIC)到新的IDT条目
9. 安装和维护IRQ
10. 管理可编程间隔定时器/系统时钟(PIT)
11. 管理键盘IRQ和键盘数据
12. ... ...其他的你来定！

## 02-准备工作

&emsp;&emsp;内核开发是编写代码以及调试各种系统组件的漫长过程。一开始这似乎是一个让人畏惧的任务, 但是并不需要大量的工具集来编写自己的内核。这个内核开发教程主要涉及使用GRUB将内核加载到内存中。GRUB需要被定向到受保护的二进制镜像中, 这个镜像就是我们将要构建的内核。

&emsp;&emsp;使用本教程, 你至少需要具备C语言基础, 并且强烈推荐了解x86汇编知识, 它允许你操作处理器中特定的寄存器。所以你至少需要一个可以生成32位编码的编译器, 一个32位的链接器和一个能生成32位x86的汇编器。

&emsp;&emsp;对于硬件, 你必须拥有一台386或者更高版本处理器的计算机。你最好有另一台计算机作为你的测试平台。如果没有第二台计算机, 使用虚拟机也是可以的(但这会导致开发速度变慢)。当你在真机上测试和调试你的内核时, 请做好无数次突然重启的准备。

- 测试平台所需硬件
  - 100%IBM兼容PC: 
  - 基于386的处理器或更高版本(建议使用486或更高版本)
  - 4MB的RAM
  - 带显示器的VGA兼容视频卡
  - 键盘
  - 软盘驱动器(是的没错, 你的测试平台甚至不需要硬盘)

- 开发平台推荐的配置
  - 100％IBM兼容PC
  - 奔腾II或K6 300MHz
  - 32MB的RAM
  - 与显示器兼容的VGA视频卡
  - 键盘
  - 一个软盘驱动器
  - 具有足够空间的硬盘, 用于存放所有开发工具、文档和源代码
  - Windows系统或类Unix系统如Linux、FreeBSD(Mac基于FreeBSD)
  - 可以联网搜索文档
  - 强烈建议使用鼠标
- 工具集
  - 编译器(选一个即可)
    - Gnu C编译器(GCC)[Unix]
    - DJGPP(用于DOS / Windows的GCC)[Windows]
  - 汇编
    - Netwide Assembler(NASM)[Unix / Windows] [安装和使用教程](https://www.cnblogs.com/raina/p/11527327.html)
  - 虚拟机(选一个即可)
    -  VMWare Workstation 4.0.5或更高版本 [Linux / Windows NT / 2000 / XP]
    - Microsoft VirtualPC [Windows NT / 2000 / XP]
    - Bochs [Unix / Windows]

## 03-内核初步

&emsp;&emsp;在这节教程, 我们将深入研究一些汇编程序, 学习创建链接脚本的基础知识以及使用它的原因。最后, 我们将学习如何使用batch(批处理)文件自动汇编、编译和链接这个最基本的受保护模式下的内核。本教程假定你已经安装了NASM和GCC, 并且了解一点点x86汇编语言。

### 内核入口

&emsp;&emsp;内核的入口点是当引导程序(bootloader)调用内核时最先执行的代码段。这段代码一直以来几乎都是使用汇编编写的, 因为有些工作如设置新的栈, 加载新的GDT、IDT或寄存器, 你简单地使用C语言根本没法做到。在很多初学者写的内核, 和更专业的内核中, 会将所有汇编程序代码放在一个文件中, 并将其余源代码分别放在几个C文件中。

&emsp;&emsp;如果至少知道一点点汇编语言, 那么下面这段汇编代码应该非常简单明了了。就代码而言, 这个文件做的只有加载一个新的8KB栈, 然后跳转到一个死循环中。这个栈是一块很小的内存, 它用于存储或传递参数给C函数。它还可以用来保存你函数中声明和使用的局部变量。其他的全局变量则存储在BSS区域中。在`mboot`和`stublet`代码块之间的代码用于生成特殊的签名, GRUB通过该签名校验即将加载的二进制输出文件, 实际上该文件就是内核。不过不用费力去理解多重引导头(multiboot header)。

&emsp;&emsp;内核启动文件**“start.asm”**的内容如下: 

> start.asm

```assembly
; 这是内核的入口点. 我们将在这里调用main函数,并设置栈和其他东西，比如：
; 创建GDT和内存区域，
; 请注意这里中断被禁用了，更多细节将在后面讲中断的时候提到
[BITS 32]
global start
start:
    mov esp, _sys_stack     ; 让当前栈指针指向我们新创建的栈
    jmp stublet             ; 跳转到stublet

; 使用'ALIGN 4'使这段代码4字节对齐
ALIGN 4
mboot:
    ; 多重引导的一些宏定义，使后面一些代码更具可读性
    MULTIBOOT_PAGE_ALIGN	equ 1<<0
    MULTIBOOT_MEMORY_INFO	equ 1<<1
    MULTIBOOT_AOUT_KLUDGE	equ 1<<16
    MULTIBOOT_HEADER_MAGIC	equ 0x1BADB002
    MULTIBOOT_HEADER_FLAGS	equ MULTIBOOT_PAGE_ALIGN | MULTIBOOT_MEMORY_INFO | MULTIBOOT_AOUT_KLUDGE
    MULTIBOOT_CHECKSUM	equ -(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS)
    EXTERN code, bss, end

    ; GRUB 多重引导头 - 启动签名
    dd MULTIBOOT_HEADER_MAGIC
    dd MULTIBOOT_HEADER_FLAGS
    dd MULTIBOOT_CHECKSUM
    
    ; 自动替换 - 必须为物理地址
    ; 注意：由链接器填充这些数据的值
    dd mboot
    dd code
    dd bss
    dd end
    dd start

; 死循环
; 之后我们将在'jmp $'前插入'extern _main'和'call _main'两句代码
stublet:
    jmp $


; GDT加载代码(以后添加)


; ISR代码(以后添加)



; BSS区的定义
; 现在问将用它来存储栈
; 栈是向下生长的，所以我们在声明'_sys_stack'
SECTION .bss
    resb 8192               ; 保留8KB内存
_sys_stack:
```

### 链接脚本

&emsp;&emsp;链接器是接收所有编译器和汇编器的输出文件, 并把它们链接成一个二进制文件的工具。二进制文件有很多种格式, 常见的有: Flat、AOUT、COFF、PE、ELF等。我们在工具集中选择的链接器是LD链接器。这是一个非常好的多功能链接器。LD链接器有多种版本, 可以输出任何你想要格式的位二进制文件。无论你选择那种输出格式, 输出的文件总由3个部分组成: 1) 'Text'或'Code'是可执行段;2) 'Data'段用于存放硬编码值(hardcoded value), 比如你声明了一个变量, 并将该变量的值设为5, 这个'5'就被存储在'Data'区域;3) 'BSS'段由未初始化的数据组成, 如没有赋值的数组。'BSS'是一个虚拟段, 它在二进制镜像中是不存在的, 但是在二进制文件加载的时候存在于内存中。

&emsp;&emsp;下面是LD链接脚本文件**"link.ld"**的内容。**`OUTPUT_FORMAT`**关键字告诉LD我们将创建哪种形式的二进制镜像, 简单起见, 我们使用'binary'二进制镜像。**`ENTRY`**用于指定哪个目标文件最先被链接。我们希望”start.asm“编译后的输出文件”start.o“为第一个链接的目标文件, 也就是没和的入口点。**`phys`**不是关键字, 而是链接脚本中使用的变量, 被用来指向内存中1MB地址的指针, 也就我们二进制文件被加载和运行的地方。**`SECTIONS`**里定义了3个主要区域: '.text'、'.data'、'.bss', 并同时定义了3个变量: 'code', 'data', 'bss', 还有 'end'。不要对此感到困惑, 其实这三个变量是我们的启动文件"start.asm"中的变量。`ALIGN(4096)`用来确保每个区域以4096B(4KB)为边界。在这种情况下, 每个部分将从内存中的单独"页"开始。

> link.ld

```assembly
OUTPUT_FORMAT("binary")
ENTRY(start)
phys = 0x00100000;
SECTIONS
{
  .text phys : AT(phys) {
    code = .;
    *(.text)
    *(.rodata)
    . = ALIGN(4096);
  }
  .data : AT(phys + (data - code))
  {
    data = .;
    *(.data)
    . = ALIGN(4096);
  }
  .bss : AT(phys + (bss - code))
  {
    bss = .;
    *(.bss)
    . = ALIGN(4096);
  }
  end = .;
}
```

### 汇编和链接

&emsp;&emsp;这里我们必须对"start.asm"进行汇编, 并使用上面的链接脚本来创建我们内核的二进制文件, 以便GRUB加载。在Unix系统中实现上述操作的最简单的方法就是创建一个makefile脚本文件来帮你汇编、编译、链接。但是大多数人使用的是Windows系统, 在Windows系统中, 我们可以创建一个batch文件。batch文件其实就是DOS命令的集合, 你可只需输入这个batch文件的文件名就可以依次执行该batch文件中的DOS命令集。更简单的方法是, 你只需要双击该batch文件, 就会在Windows系统下自动执行DOS命令编译你的内核。

&emsp;&emsp;下面是本教程使用的batch文件**"build.bat"**。`echo`是一个DOS命令, 用来向终端显示字符。`nasm`是我们使用的汇编器, 我们以aout的格式编译, 因为LD链接器需要一种已知格式才能解析链接过程中的符号。汇编器将’start.asm'汇编成'start.o'。`rem`命令是注释, 在运行batch文件是会将它忽略。`ld`是我们的链接器, '-T'参数告诉链接器我们使用哪一个链接脚本, `-o`用来指定输出文件名。其他的参数都将被链接器理解为需要链接到一起并解析生成kernel.bin的文件。最后, `pause`命令将在屏幕上显示"Press a key to continue..."并等待我们按下键盘上的任意键, 这方便我们查看汇编器或链接器在语法错误上给出了哪些提示。

> build.bat

```bash
echo Now assembling, compiling, and linking your kernel:
nasm -f aout -o start.o start.asm
rem Remember this spot here: We will add 'gcc' commands here to compile C sources


rem This links all your files. Remember that as you add *.o files, you need to
rem add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -o kernel.bin start.o
echo Done!
pause
```

### PS: 下面是我自己写的

#### 64位Linux下的编译脚本

> build.sh

```bash
echo "Now assembling, compiling, and linking your kernel:"
nasm -f elf64 -o start.o start.asm
# Remember this spot here: We will add 'gcc' commands here to compile C sources

# This links all your files. Remember that as you add *.o files, you need to
# add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -o kernel.bin start.o
echo "Done!"
```

使用下面指令运行: 

```bash
bash build.sh
```

## 04-创建main函数和链接C文件

&emsp;&emsp;一般C语言使用main()函数作为程序的入口点, 为了符合我们平时的编程习惯, 这里我们也使用main()函数作为C代码的入口点, 并在"start.asm"文件中添加中断服务程序来调用C函数。

&emsp;&emsp;在这一节教程,我们将尝试创建一个"main.c"文件和一个包含常用函数原型的头文件"system.h"。"main.c"中包含mian()函数, 它将作为你C代码的入口。在内核开发中, 我们一般不从main()函数返回。多数操作系统在main中初始化内核和子程序、加载shell, 然后main函数会进入空循环中。在多任务系统中, 当没有其他需要运行的任务时, 将一直执行这个空循环。下面是"main.c"文件的示例,其中包含了最基本的main()函数和一些我们以后会用到的函数体。

> main.c

```cpp
#include <system.h>

/* 你将要自己完成这些代码  */
unsigned char *memcpy(unsigned char *dest, const unsigned char *src, int count)
{
    /* 在此处添加代码, 将'src'中count字节的数据复制到'dest'中, 
     *  最后返回'dest' */
}

unsigned char *memset(unsigned char *dest, unsigned char val, int count)
{
    /* 在此处添加代码, 将'dest'中的count字节全部设置成值'val', 
     * 最后返回'dest' */
}

unsigned short *memsetw(unsigned short *dest, unsigned short val, int count)
{
    /* 在此处添加代码, 将'dest'中的count双字节设置成值'val', 
     * 最后返回'dest' 
     * 注意'val'是双字节 16-bit*/
}

int strlen(const char *str)
{
    /* 返回字符串的长度
     * 遇到某个字节的值为0x00结束 */
}

/* 我们之后将使用这个函数通过IO端口从设备读取数据, 如键盘等
 * 我们使用内联汇编代码(inline assembly)实现该功能 */
unsigned char inportb (unsigned short _port)
{
    unsigned char rv;
    __asm__ __volatile__ ("inb %1, %0" : "=a" (rv) : "dN" (_port));
    return rv;
}

/* 我们将使用这个函数通过I/O端口向设备写数据
 * 用来修改文本模式和光标位置
 * 同样,我们使用内联汇编来实现这个单用C无法实现的功能 */
void outportb (unsigned short _port, unsigned char _data)
{
    __asm__ __volatile__ ("outb %1, %0" : : "dN" (_port), "a" (_data));
}

/* 这是一个非常简单的main函数, 它内部仅进行死循环 */
void main()
{
    /* 你可以在这里添加语句 */

    /* 保留此循环
    *  不过, 在'start.asm'里也有一个无限循环, 防止你不小心删除了下面这一行*/
    for (;;);
}
```

&emsp;&emsp;在你编译之前, 我们需要在'start.asm'中添加2行代码。我们需要让编译器知道main()在外部文件中, 我们还需要从'start.asm'文件中调用main()函数。打开'start.asm'文件, 在`stublet:`的下面添加下面2行代码: 

```assembly
	extern _main
	call _main
```

&emsp;&emsp;先等等编译, `_main`前面的下划线是什么东西, 我们在C语言里声明的是`main`啊？编译器gcc在编译时会在所有函数和变量名前面加上下划线。因此, 要从汇编中引用C文件中的函数和变量, 我们都需要在前面加上下划线！

&emsp;&emsp;现在我们还缺少一个"system.h"文件。创建一个名为"include"的文件夹, 在该文件加下创建一个名为"system.h"的空白文本文件, 将`mencpy`、`memset`、`memsetw`、`strlen`、`inportb`、`outportb`这些函数的函数原型添加到该头文件中。`#ifndef`、`#define`、`#endif`用于防止头文件被多次声明。这个头文件用来包含你在内核中使用的所有函数, 你可以随意添加你需要的函数来扩展此库。

> include/system.h

```cpp
#ifndef __SYSTEM_H
#define __SYSTEM_H

/* MAIN.C */
extern unsigned char *memcpy(unsigned char *dest, const unsigned char *src, int count);
extern unsigned char *memset(unsigned char *dest, unsigned char val, int count);
extern unsigned short *memsetw(unsigned short *dest, unsigned short val, int count);
extern int strlen(const char *str);
extern unsigned char inportb (unsigned short _port);
extern void outportb (unsigned short _port, unsigned char _data);

#endif
```

&emsp;&emsp;接下来, 我们要来编译这些文件。打开之前的"build.bat"文件, 添加下面一行命令来编译你的"main.c"。这个命令运行了gcc编译器, `gcc`后面有一堆参数: 

- `-Wall`用于显示所有的警告
- `-O`、`-fstrength-reduce`、`-fomit-frame-pointer`、`-finline-functions`用于编译优化
- `-nostdinc`和`-fno-builtin`告诉编译器我们将不适用C标准库函数
- `-I./include`告诉编译器我们的头文件在当前文件夹下的"include"文件夹里
- `-c`表示当前仅编译, 不链接
- `-o main.o`表示输出文件名为main.o
- `main.c`是我们要编译的文件

```bash
gcc -Wall -O -fstrength-reduce -fomit-frame-pointer -finline-functions -nostdinc -fno-builtin -I./include -c -o main.o main.c
```

&emsp;&emsp;别忘了, 按照"build.bat"文件中的指示, 把"main.o"添加到链接文件的列表中去。像这样: 

```bash
ld -T link.ld -o kernel.bin start.o main.o
```

&emsp;&emsp;当前完整的"build.bat"文件内容如下: 

> build.bat

```bash
echo Now assembling, compiling, and linking your kernel:
nasm -f aout -o start.o start.asm
rem Remember this spot here: We will add 'gcc' commands here to compile C sources
gcc -Wall -O -fstrength-reduce -fomit-frame-pointer -finline-functions -nostdinc -fno-builtin -I./include -c -o main.o main.c


rem This links all your files. Remember that as you add *.o files, you need to
rem add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -o kernel.bin start.o main.o
echo Done!
pause
```

&emsp;&emsp;最后, 如果你不知道该怎么实现那些附加函数, 如`memcpy`函数, 这里有一份参考代码: 

```cpp
#include <system.h>

unsigned char *memcpy(unsigned char *dest, const unsigned char *src, int count)
{
    const unsigned char *sp = (const unsigned char *)src;
    unsigned char *dp = dest;
    for(; count != 0; count--) *dp++ = *sp++;
    return dest;
}

unsigned char *memset(unsigned char *dest, unsigned char val, int count)
{
    unsigned char *temp = (unsigned char *)dest;
    for( ; count != 0; count--) *temp++ = val;
    return dest;
}

unsigned short *memsetw(unsigned short *dest, unsigned short val, int count)
{
    unsigned short *temp = (unsigned short *)dest;
    for( ; count != 0; count--) *temp++ = val;
    return dest;
}

int strlen(const char *str)
{
    int retval;
    for(retval = 0; *str != '\0'; str++) retval++;
    return retval;
}

/* 我们之后将使用这个函数通过IO端口从设备读取数据, 如键盘等
 * 我们使用内联汇编代码(inline assembly)实现该功能 */
unsigned char inportb (unsigned short _port)
{
    unsigned char rv;
    __asm__ __volatile__ ("inb %1, %0" : "=a" (rv) : "dN" (_port));
    return rv;
}

/* 我们将使用这个函数通过I/O端口向设备写数据
 * 用来修改文本模式和光标位置
 * 同样,我们使用内联汇编来实现这个单用C无法实现的功能 */
void outportb (unsigned short _port, unsigned char _data)
{
    __asm__ __volatile__ ("outb %1, %0" : : "dN" (_port), "a" (_data));
}

/* 这是一个非常简单的main函数, 它内部仅进行死循环 */
void main()
{
    /* 你可以在这里添加语句 */

    /* 保留此循环
    *  不过, 在'start.asm'里也有一个无限循环, 防止你不小心删除了下面这一行*/
    for (;;);
}
```

### PS: 下面是我自己写的

#### Win10安装gcc编译器

&emsp;&emsp;Win10安装gcc、g++、make: https://www.cnblogs.com/raina/p/10656106.html

#### 本节教程对应的Linux下的编译脚本

```bash
echo "Now assembling, compiling, and linking your kernel:"
nasm -f elf64 -o start.o start.asm
# Remember this spot here: We will add 'gcc' commands here to compile C sources
gcc -Wall -O -fstrength-reduce -fomit-frame-pointer -finline-functions -nostdinc -fno-builtin -I./include -c -o main.o main.c

# This links all your files. Remember that as you add *.o files, you need to
# add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -o kernel.bin start.o main.o
echo "Done!"
read -p "Press a key to continue..."
```

#### \_main的问题

&emsp;&emsp;我的gcc版本是7.4.0, 在编译C程序时并没有在函数和变量名前面自己加下划线, 所以按照原教程写的汇编代码, 编译后会报下面的错误: 

> start.o: In function `stublet':
> start.asm:(.text+0x29): undefined reference to `_main'

把"start.asm"里`_main`的下划线去掉, 再编译就行了。

## 05-打印到屏幕

&emsp;&emsp;现在, 我们需要尝试打印到屏幕上。为此, 我们需要管理屏幕滚动, 如果能允许使用不同的颜色就更好了。好在VGA视频卡为我们提供了一片内存空间, 允许同时写入属性字节和字符字节对, 可以更简单地在屏幕上显示信息。VGA控制器负责自动绘制屏幕上的更新。屏幕滚动由内核软件来管理。从技术上讲, 这将是我们写的第一个驱动程序。

&emsp;&emsp;如上所述, 文本空间只是我们地址空间的一块存储区域, 这片缓冲区位于物理内存的0xB800地址, 缓冲区的数据类型为"short"类型, 这意味着这片文本存储序列的每一项是16bit的, 而不是我们认为的8bit。每个16bit元素可以被分解为高8位和低8位。低8位用于告诉显示控制器在屏幕上绘制什么字符, 称为"字符字节(character byte)"; 高8位称为"属性字节(attribute byte)", 用于定义要绘制字符的前景色和背景色。

<table cols="50,50,50,50,100,100">
    <tr>
        <td width="50" align="left">
            15
        </td>
        <td width="50" align="right">
            12
        </td>
        <td width="50" align="left">
            11
        </td>
        <td width="50" align="right">
            8
        </td>
        <td width="100" align="left">
            7
        </td>
        <td width="100" align="right">
            0
        </td>
    </tr>
</table>
<table cols="100, 100, 200" border="1">
    <tr>
        <td width="100" align="center">
            Backcolor
        </td>
        <td width="100" align="center">
            Forecolor
        </td>
        <td width="200" align="center">
            Character
        </td>
    </tr>
</table>

由于只有4位用来表示1种颜色, 所以最多只能表示16种不同颜色, 下面是默认的16色调色板: 

<table cols="50, 200, 50, 200">
    <tr>
      <th align="left" width="50">Value</th>
      <th align="left" width="200">Color</th>
      <th align="left" width="50">Value</th>
      <th align="left" width="200">Color</th>
    </tr>
    <tr>
      <td width="50">
        0
      </td>
      <td width="200">
        <font color="black">BLACK</font>
      </td>
      <td width="50">
        8
      </td>
      <td width="200">
        <font color="#444444">DARK GREY</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        1
      </td>
      <td width="200">
        <font color="#0000FF">BLUE</font>
      </td>
      <td width="50">
        9
      </td>
      <td width="200">
        <font color="#3399FF">LIGHT BLUE</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        2
      </td>
      <td width="200">
        <font color="#00FF00">GREEN</font>
      </td>
      <td width="50">
        10
      </td>
      <td width="200">
        <font color="#99FF66">LIGHT GREEN</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        3
      </td>
      <td width="200">
        <font color="#00FFFF">CYAN</font>
      </td>
      <td width="50">
        11
      </td>
      <td width="200">
        <font color="#CCFFFF">LIGHT CYAN</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        4
      </td>
      <td width="200">
        <font color="#FF0000">RED</font>
      </td>
      <td width="50">
        12
      </td>
      <td width="200">
        <font color="#FF6600">LIGHT RED</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        5
      </td>
      <td width="200">
        <font color="#CC0099">MAGENTA</font>
      </td>
      <td width="50">
        13
      </td>
      <td width="200">
        <font color="#FF66FF">LIGHT MAGENTA</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        6
      </td>
      <td width="200">
        <font color="#663300">BROWN</font>
      </td>
      <td width="50">
        14
      </td>
      <td width="200">
        <font color="#CC6600">LIGHT BROWN</font>
      </td>
    </tr>
    <tr>
      <td width="50">
        7
      </td>
      <td width="200">
        <font color="#CCCCCC">LIGHT GREY</font>
      </td>
      <td width="50">
        15
      </td>
      <td width="200">
        <font color="grey">WHITE</font>
      </td>
    </tr>
</table>

&emsp;&emsp;最后, 文本模式存储器是一片线性的区域, 每行文本在内存中是连续的。但是视频控制器让它看上去像一个大小为80x25、值为16bit的矩阵(25行x80个字符)。为了把屏幕上的字符位置和内存索引对应, 我们需要用到下面的公式: 
$$
index = (y\_value * width\_of\_screen) + x\_value;
$$
举个例子, 如果我们要在屏幕(3, 4)的位置上显示字符`character`, 则它在内存中的索引为`4 * 80 + 3`为323, 程序的代码类似于这样: 

```cpp
unsigned short *where = (unsigned short *)0xB8000 + 323;
*where = character | (attribute << 8);
```

&emsp;&emsp;下面是"scrn.c"文件的内容, 该文件包含我们用于处理屏幕的所有函数。包含"system.h"方便我们调用`outportb`、`memcpy`、`memset`、`memsetw`和`strlen`函数。我们使用的滚动方法非常有趣: 我们从第1行开始获取文本存储块, 并将其复制到顶部的第0行。这就将整个屏幕向上移动了一行。 为了完成滚动, 我们通过写入空格来擦除文本的最后一行。 `putch`函数可能是此文件中最复杂的函数, 因为它需要处理换行符('\n'), 回车符('\r')和退格键('\ b')。 如果你愿意, 可以处理警报字符('\a'-ASCII值为7), 在遇到报警符时发出一声短促的哔声。 我还提供了一个设置屏幕颜色的函数`settextcolor`。

> scrn.c

```cpp
#include <system.h>

unsigned short *textmemptr;  // 文本指针
int attrib = 0x0F;  // 属性
int csr_x = 0, csr_y = 0;  // x和y的坐标

/* 屏幕滚动 */
void scroll(void)
{
    unsigned blank, temp;

    /* 空格 */
    blank = 0x20 | (attrib << 8);

    /* 第25行是最后一行, 我们需要向上滚动了 */
    if(csr_y >= 25)
    {
        /* 将24行往上平移一行 */
        temp = csr_y - 25 + 1;
        memcpy (textmemptr, textmemptr + temp * 80, (25 - temp) * 80 * 2);

        /* 最后一行填充空格 */
        memsetw (textmemptr + (25 - temp) * 80, blank, 80);
        csr_y = 25 - 1;
    }
}

/* 更新光标位置: 在最后一个字符下添加一条闪烁的下划线 */
void move_csr(void)
{
    unsigned temp;

    /* 虚拟坐标与物理地址转换的公式:
     * Index = [(y * width) + x] */
    temp = csr_y * 80 + csr_x;

    /* 往VAG的CRT控制寄存器内发送命令, 设置光标的高地址和低地址
     * 想了解更多细节, 需要查找VGA编程文档 */
    outportb(0x3D4, 14);  // 设置光标高8位地址
    outportb(0x3D5, temp >> 8);
    outportb(0x3D4, 15);  // 设置光标低8位地址
    outportb(0x3D5, temp);
}

/* 清空屏幕 */
void cls()
{
    unsigned blank;
    int i;

    /* 带颜色的空格 */
    blank = 0x20 | (attrib << 8);

    /* 将整个屏幕用空格填充 */
    for(i = 0; i < 25; i++)
        memsetw (textmemptr + i * 80, blank, 80);

    /* 更新虚拟坐标, 并移动光标 */
    csr_x = 0;
    csr_y = 0;
    move_csr();
}

/* 打印单个字符 */
void putch(unsigned char c)
{
    unsigned short *where;
    unsigned att = attrib << 8;

    /* 处理退格键, 往回移动光标一格 */
    if(c == 0x08)
    {
        if(csr_x != 0) csr_x--;
    }
    /* 处理Tab键, 增大光标的x坐标, 并且只增加到x坐标可以整除8的位置 */
    else if(c == 0x09)
    {
        csr_x = (csr_x + 8) & ~(8 - 1);
    }
    /* 处理回车键, 将光标回退到行首 */
    else if(c == '\r')
    {
        csr_x = 0;
    }
    /* 处理换行, 光标移动到下一行行首 */
    else if(c == '\n')
    {
        csr_x = 0;
        csr_y++;
    }
    /* 所有ASCII值大于等于空格的字符都是可打印的字符 */
    else if(c >= ' ')
    {
        where = textmemptr + (csr_y * 80 + csr_x);
        *where = c | att;	/* 设置字符和颜色 */
        csr_x++;
    }

    /* 当光标到达屏幕又边界, 移动到下一行行首 */
    if(csr_x >= 80)
    {
        csr_x = 0;
        csr_y++;
    }

    /* 在需要的时候滚动屏幕, 并移动光标 */
    scroll();
    move_csr();
}

/* 使用putch来打印字符串 */
void puts(unsigned char *text)
{
    int i;

    for (i = 0; i < strlen(text); i++)
    {
        putch(text[i]);
    }
}

/* 设置前景色和背景色 */
void settextcolor(unsigned char forecolor, unsigned char backcolor)
{
    /* 前4bit为背景色, 后4bit为前景色 */
    attrib = (backcolor << 4) | (forecolor & 0x0F);
}

/* 设置文本模式VGA指针, 并清屏 */
void init_video(void)
{
    textmemptr = (unsigned short *)0xB8000;
    cls();
}

```

&emsp;&emsp;接下来我们需要将它编译进内核中。首先需要在"build.bat"中添加一行gcc编译命令。复制编译"main.c"的那行命令, 在它的下面一行粘贴, 然后将里面的"main"修改为"scrn"即可。还有, 不要忘记把"scrn.o"添加到链接文件的列表中。为了让main函数能调用"scrn.c"文件中的这些函数, 需要将`putch`、`puts`、`cls`、`init_video`和`settextcolor`的函数原型添加到"system.h"中, 不要忘记"extern"关键字, 因为它们都是函数原型。

> system.h

```cpp
extern void cls();
extern void putch(unsigned char c);
extern void puts(unsigned char *str);
extern void settextcolor(unsigned char forecolor, unsigned char backcolor);
extern void init_video();
```

&emsp;&emsp;现在可以在main函数中调用我们的屏幕打印函数了。打开"main.c"文件, 添加一行调用`init_video()`函数, 然后使用`puts()`打印"Hello World!", 最后保存所有修改, 运行"build.bat"文件, 调试所有语法错误。将"kernel.bin"复制到你的GRUB软盘上, 如果一切顺利, 你讲在你的黑底的屏幕上看见白色的"Hello World!"文本。

## 06-全局描述符表(GDT)

&emsp;&emsp;在386平台各种保护措施中最重要的就是全局描述符表(GDT)。GDT为内存的某些部分定义了基本的访问权限。我们可以使用GDT中的一个索引来生成段冲突异常, 让内核终止执行异常的进程。现代操作系统大多使用"分页"的内存模式来实现该功能, 它更具通用性和灵活性。GDT还定义了内存中的的某个部分是可执行程序还是实际的数据。GDT还可定义任务状态段(TSS)。TSS一般在基于硬件的多任务处理中使用, 所以我们在此并不做讨论。需要注意的是TSS并不是启用多任务的唯一方法。

&emsp;&emsp;注意GRUB已经为你安装了一个GDT, 如果我们重写了加载GRUB的内存区域, 将会丢弃它的GDT, 这会导致"三重错误(Triple fault)"。简单的说, 它将重置机器。为了防止该问题的发生, 我们应该在已知可以访问的内存中构建自己的GDT, 并告诉处理器它在哪里, 最后使用我们的新索引加载处理器的CS、DS、ES、FS和GS寄存器。CS寄存器就是代码段, 它告诉处理器执行当前代码的访问权限在GDT中的偏移量。DS寄存器的作用类似, 但是数据段, 定义了当前数据的访问权限的偏移量。ES、FS和GS是备用的DS寄存器, 对我们并不重要。

&emsp;&emsp;GDT本身是64位的长索引列表。这些索引定义了内存中可访问区域的起始位置和大小界限, 以及与该索引关联的访问权限。通常第一个索引, 0号索引被称为NULL描述符。所以我们不应该将任何的段寄存器设置为0, 否则将导致常见的保护错误, 这也是处理器的保护功能。通用的保护错误和几种异常将在中断服务程序(ISR)那节详细说明。

&emsp;&emsp;每个GDT索引还定义了处理器正在运行的当前段是供系统使用的(Ring 0)还是供应用程序使用的(Ring 3)。也有其他Ring级别, 但并不重要。当今主要的操作系统仅使用Ring 0和Ring 3。任何应用程序在尝试访问系统或Ring 0的数据时都会导致异常, 这种保护是为了防止应用程序导致内核崩溃。GDT的Ring级别用于告诉处理器是否允许其执行特殊的特权指令。具有特权的指令只能在更高的Ring级别上运行。例如"cli"和"sti"禁用和启用中断, 如果应用程序被允许使用这两个指令, 它就可以阻止内核的运行。你将在本教程的后续章节中了解更多有关中断的知识。

&emsp;&emsp;GDT的描述符组成如下: 

![1570523285417](/home/raina/Documents/Workspace/notes/markdownPics/bkerndev/1570523285417.png)

- G: 段界限粒度(Granularity)
  - G = 0: 长度单位为1字节
  - G = 1: 长度单位为4KB
- D: 操作数大小
  - 0 = 16bit
  - 1 = 32bit
- L: 未使用为0
- AVL: 保留位, 系统软件使用
- P: 存在位, 段是否存在
  - 1 = Yes
  - 0 = No
- DPL: Ring级别(0到3)
- S: 描述符类型位
  - S = 1: 存储段描述符, 数据段/代码段
  - S = 0: 系统段描述符/门描述符)
- TYPE: 段类型

&emsp;&emsp;在我们的内核教程中, 我们将创建一个包含3个索引的GDT。一个用于''虚拟''描述符充当处理器内存保护功能的NULL段, 一个用于代码段, 一个用于数据段寄存器。使用汇编操作码`lgdt`告诉处理器我们新的GDT表在哪里。为`lgdt`提供一个指向48位的专用的全局描述符表寄存器(GDTR)的指针。该寄存器用来保存全局描述符信息, 0-15位表示GDT的边界位置(数值为表的长度-1), 16-47位存放GDT基地址。并且在我们访问GDT中不存在偏移的段时, 希望处理器可以立即创建一般保护错误)。

&emsp;&emsp;我们可以使用3个索引的简单数组来定义GDT。对于我们的特殊GDTR指针, 我们只需要声明一个即可。我们称其为`gp`。创建一个新文件**gdt.c**。在**build.bat**中添加一行gcc命令来编译**gdt.c**, 并将**gdt.o**添加到LD链接文件列表中。下面这些代码组成了**gdt.c**的前半部分: 

> gdt.c

```c
#include <system.h>

/* 定义一个GDT索引. __attribute__((packed))用于防止编译器优化对齐 */
struct gdt_entry
{
    unsigned short limit_low;
    unsigned short base_low;
    unsigned char base_middle;
    unsigned char access;
    unsigned char granularity;
    unsigned char base_high;
} __attribute__((packed));

/* GDTR指针 */
struct gdt_ptr
{
    unsigned short limit;
    unsigned int base;
} __attribute__((packed));

/* 声明包含3个索引的GDT和GDTR指针gp */
struct gdt_entry gdt[3];
struct gdt_ptr gp;

/* 这是start.asm中的函数, 用来加载新的段寄存器 */
extern void gdt_flush();
```

&emsp;&emsp;`gdt_flush()`我们还没有定义, 该函数使用上面的GDTR指针来告诉处理器新的GDT所在位置, 并重新加载段寄存器, 最后跳转到我们的新代码段。现在我们在**start.asm**的`stublet`下的死循环后面添加下面的代码来定义`gdt_flush`: 

> start.asm

```assembly
; 这将建立我们新的段寄存器
; 通过长跳转来设置CS
global _gdt_flush     ; 允许C源程序链接该函数
extern _gp            ; 声明_gp为外部变量
_gdt_flush:
    lgdt [_gp]        ; 用_gp来加载GDT
    mov ax, 0x10      ; 0x10是我们数据段在GDT中的偏移地址
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:flush2   ; 0x08是代码段的偏移地址, 长跳转
flush2:
    ret               ; 返回到C程序中
```

&emsp;&emsp;仅为GDT保留内存空间是不够的, 还需要将值写入每个GDT中, 设置`gp`指针, 再调用`gdt_flush`进行更新。定义`gdt_set_entry()`函数, 该函数使用函数参数的移位给GDT每个字段设置值。为了让**main.c**能够使用这些函数, 别忘了将它们添加到**system.h**中(至少需要把`gdt_install`添加进去)。下面为**gdt.c**的剩下部分: 

> gdt.c

```c
/* 在全局描述符表中设置描述符 */
void gdt_set_gate(int num, unsigned long base, unsigned long limit, unsigned char access, unsigned char gran)
{
    /* 设置描述符基地址 */
    gdt[num].base_low = (base & 0xFFFF);
    gdt[num].base_middle = (base >> 16) & 0xFF;
    gdt[num].base_high = (base >> 24) & 0xFF;

    /* 设置描述符边界 */
    gdt[num].limit_low = (limit & 0xFFFF);
    gdt[num].granularity = ((limit >> 16) & 0x0F);

    /* 最后，设置粒度和访问标志 */
    gdt[num].granularity |= (gran & 0xF0);
    gdt[num].access = access;
}

/* 由main函数调用
 * 设置GDTR指针, 设置GDT的3个索引条码
 * 最后调用汇编中的gdt_flush告诉处理器新GDT的位置
 * 并跟新新的段寄存器 */
void gdt_install()
{
    /* 设置GDT指针和边界 */
    gp.limit = (sizeof(struct gdt_entry) * 3) - 1;
    gp.base = &gdt;

    /* NULL描述符 */
    gdt_set_gate(0, 0, 0, 0, 0);

    /* 第2个索引是我们的代码段
     * 基地址是0, 边界为4GByte, 粒度为4KByte
     * 使用32位操作数, 是一个代码段描述符
     * 对照本教程中GDT的描述符的表格
     * 弄清每个值的含义 */
    gdt_set_gate(1, 0, 0xFFFFFFFF, 0x9A, 0xCF);

    /* 第3个索引是数据段
     * 与代码段几乎相同
     * 但access设置为数据段 */
    gdt_set_gate(2, 0, 0xFFFFFFFF, 0x92, 0xCF);

    /* 清除旧的GDT安装新的GDT */
    gdt_flush();
}
```

&emsp;&emsp;现在我们的GDT加载程序的基本结构已经到位, 在将其编译链接到内核中后, 我们需要在**main.c**中调用`gdt_install()`才能真正完成工作。在`main()`函数的第一行添加`gdt_install();`GDT加载必须最先初始化。现在, 编译你的内核, 并在软盘中对其进行测试, 你不会在屏幕上看到任何变化, 这是一个内部的更改。

&emsp;&emsp;下面我们将进入中断描述符表(IDT)！

### PS

&emsp;&emsp;如果编译的时候报错: 

> undefined reference to \`\_gp'
> undefined reference to \`gdt\_flush'

则把**start.asm**中`_gp`和`_gdt_flush`前面的下划线去掉再重新编译。



## 07-中断描述符表(IDT)

&emsp;&emsp;中断描述符表(IDT)用于告诉处理器调用哪个中断服务程序(ISR)来处理异常或汇编中的"int"指令。每当设备完成请求并需要服务事, 中断请求也会调用IDT条目。异常和ISR将在下一节进行详细的说明。

&emsp;&emsp;每一项IDT都与GDT相似, 两者都有一个基地址, 一个访问标志, 而且都长64bits。这两类描述符表最主要的区别在于这些字段的含义: 在IDT中的基地址是中断时应调用的ISR的地址。IDT也没有边界(limit), 而是需要一个指定的段, 该段与给定的ISR所在段相同。这让处理器即使处于不同级别的Ring中, 在发生中断时也能将控制权交给内核。

&emsp;&emsp;IDT条目的访问标志位也和GDT相似。需要一个字段说明描述符是否存在。描述符特权级别(DPL)用于说明哪个Ring是给定中断允许使用的最高级别。主要区别在于访问字节的低5位始终为二进制01110, 也就是十进制中的14。下面这张表让你更好地理解IDT访问字节。

<table>
			<tbody><tr>
				<td>
					<table cols="25, 25, 25, 25, 100">
						<tbody><tr>
							<td width="25" align="center">7</td>
							<td width="25" align="left">6</td>
							<td width="25" align="right">5</td>
							<td width="25" align="left">4</td>
							<td width="100" align="right">0</td>
						</tr>
					</tbody></table>
				</td>
			</tr>
			<tr>
				<td>
					<table cols="25, 50, 125" bordercolor="#808080" border="1">
						<tbody><tr>
							<td width="25">
								P
							</td>
							<td width="50">
								DPL
							</td>
							<td width="125">
								Always 01110 (14)
							</td>
						</tr>
					</tbody></table>
				</td>
			</tr>
			<tr>
				<td>
					P - 段是否存在? (1 = Yes)<br>
					DPL - 哪个Ring (0~3)<br>
				</td>
			</tr>
		</tbody></table>

&emsp;&emsp;在你的自制内核目录下创建一个新文件**"idt.c"**。编辑**"build.bat"**文件, 添加新的一行gcc命令编译**"idt.c"**。最后添加**"idt.o"**到链接文件列表中。**"idt.c"**中将会声明一个结构体用于定义每个IDT条目,  和一个用于加载IDT的特殊IDT指针结构体(类似于加载GDT, 但工作量更少), 并声明一个256大小的IDT数组: 这将成为我们的IDT。

> idt.c

```c
#include <system.h>

/* 定义IDT条目 */
struct idt_entry
{
    unsigned short base_lo;
    unsigned short sel;        /* 我们的内核段在这里 */
    unsigned char always0;     /* 这将始终为0! */
    unsigned char flags;       /* 根据上表进行设置! */
    unsigned short base_hi;
} __attribute__((packed));  // 不进行对齐优化

struct idt_ptr
{
    unsigned short limit;
    unsigned int base;
} __attribute__((packed));

/* 声明一个有256个条目的IDT, 尽管在本教程中我们只会使用前32个。
 * 剩下的存在一点小陷阱, 如果任何未定义的IDT被集中, 
 * 将会导致"未处理的中断(Unhandled Interrupt)"异常,
 * 描述符的"presence"位如果为0, 将生成"未处理的中断"异常。*/
struct idt_entry idt[256];
struct idt_ptr idtp;

/*该函数在"start.asm"中定义, 用于加载我们的IDT */
extern void idt_load();
```

&emsp;&emsp;`idt_load`函数的函数定义在其他文件中, 和`gdt_flash`一样是使用汇编语言编写的。我们之后将在`idt_install`中使用创建的IDT指针来调用`lidt`汇编操作码。打开**"start.asm"**文件, 把下面几行添加到`_gdt_flush`的`re`后面。

> start.asm

```assembly
; 加载idtp指针所指的IDT到处理器中
; 这在C文件中声明为"extern void idt_load();"
global _idt_load
extern _idtp
_idt_load:
    lidt [_idtp]
    ret
```

&emsp;&emsp;设置IDT条目比GDT简单得多。我们又一个`idt_set_gate`函数用于接收IDT索引号、中断服务程序基地址、内核代码段以及上表中提到的访问标志。同样, 我们又一个`idt_install`函数用来设置IDT指针, 并将IDT初始化为默认清除状态。最后, 我们将通过调用`idt_load`来加载IDT。在加载IDT后, 我们可以随时将ISR添加到IDT中。本教程将在下一节介绍ISR。下面是**"idt.c"**文件的剩余部分, 请尝试弄明白`idt_set_gate`函数, 它其实很简单。

> idt.c

```c
/* 使用该函数来设置每项IDT*/
void idt_set_gate(unsigned char num, unsigned long base, unsigned short sel, unsigned char flags)
{
    /* 该函数的代码将留给你来实现: 
     * 将参数"base"分为高16位和低16位,
     * 将它们存储在idt[num].base_hi和idt[num].base_lo中
     * 剩下的需要设置idt[num]的其他成员的值 */
}

/* 安装IDT */
void idt_install()
{
    /* 设置IDT指针 */
    idtp.limit = (sizeof (struct idt_entry) * 256) - 1;
    idtp.base = &idt;

    /* 清空整个IDT, 并初始化该片区域为0 */
    memset(&idt, 0, sizeof(struct idt_entry) * 256);

    /* 使用idt_set_gate将ISR添加到IDT中 */

    /* 将处理器的内部寄存器指向新的IDT */
    idt_load();
}
```

&emsp;&emsp;最后, 确保在**"system.h"**中添加`idt_set_gate`和`idt_install`作为函数原型, 因为我们需要从其他文件(例如**"main.c"**)中调用这些函数。在`main()`函数调用了`gdt_install`后立即调用`idt_install`。这是你应该可以成功编译你的内核。尝试使用一下你的新内核, 在进行除零之类的非法操作时, 计算机将重置。我们可以通过在新的IDT中安装ISR来不活这些异常。

&emsp;&emsp;如果你不知道怎么编写`idt_set_gate`, 则可以在此处找到本教程的解决方案。

> idt.c

```c
void idt_set_gate(unsigned char num, unsigned long base, unsigned short sel, unsigned char flags)
{
    /* 中断程序的基地址 */
    idt[num].base_lo = (base & 0xFFFF);
    idt[num].base_hi = (base >> 16) & 0xFFFF;

    /* 该IDT使用的段或区域以及访问标志位将在此设置 */
    idt[num].sel = sel;
    idt[num].always0 = 0;
    idt[num].flags = flags;
}
```

## 08-中断服务程序(ISR)

&emsp;&emsp;中断服务程序(ISR)用于保存当前处理器的状态, 并在调用内核的C级中断处理程序之前正确设置内核模式所需的段寄存器。而工作只需要15到20行汇编代码来处理, 包括调用C中的处理程序。我们还需要将IDT条目指向正确的ISR以正确处理异常。

&emsp;&emsp;异常是导致处理器无法正常执行的特殊情况, 比如除以0结果是未知数或者非实数, 因此处理器会抛出异常, 这样内核就可以阻止进程或任务引起任何问题。如果处理器发现程序正尝试访问不允许其访问的内存, 则会引起一般保护错误。当你设置内存页时, 处理器将会产生页面错误, 但这是可以恢复的: 你可以将内存页映射到错误的地址(但这需要另开一篇教程来讲解)。

&emsp;&emsp;IDT的前32个条目与处理器可能产生的异常对应, 因此需要对其进行处理。某些异常会将另一个值压入堆栈中: 错误代码, 该值为每个异常的特定代码。

<table>
<tbody><tr>
				<th width="100" align="left">
					Exception #
				</th>
				<th width="300" align="left">
					Description
				</th>
				<th width="100" align="left">
					Error Code?
				</th>
			</tr>
			<tr>
				<td width="100">0</td>
				<td width="300">Division By Zero Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">1</td>
				<td width="300">Debug Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">2</td>
				<td width="300">Non Maskable Interrupt Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">3</td>
				<td width="300">Breakpoint Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">4</td>
				<td width="300">Into Detected Overflow Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">5</td>
				<td width="300">Out of Bounds Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">6</td>
				<td width="300">Invalid Opcode Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">7</td>
				<td width="300">No Coprocessor Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">8</td>
				<td width="300">Double Fault Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">9</td>
				<td width="300">Coprocessor Segment Overrun Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">10</td>
				<td width="300">Bad TSS Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">11</td>
				<td width="300">Segment Not Present Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">12</td>
				<td width="300">Stack Fault Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">13</td>
				<td width="300">General Protection Fault Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">14</td>
				<td width="300">Page Fault Exception</td>
				<td width="100">Yes</td>
			</tr>
			<tr>
				<td width="100">15</td>
				<td width="300">Unknown Interrupt Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">16</td>
				<td width="300">Coprocessor Fault Exception</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">17</td>
				<td width="300">Alignment Check Exception (486+)</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">18</td>
				<td width="300">Machine Check Exception (Pentium/586+)</td>
				<td width="100">No</td>
			</tr>
			<tr>
				<td width="100">19 to 31</td>
				<td width="300">Reserved Exceptions</td>
				<td width="100">No</td>
			</tr>
		</tbody>
</table>

&emsp;&emsp;之前提到, 一些异常会错误码压入堆栈中, 为了降低复杂度, 我们为尚未压入错误码的ISR将伪错误码0压入堆栈中, 这样可以保持统一的堆栈结构。为了跟踪触发的是哪个异常, 我们将中断号也压入堆栈。我们使用汇编操作码"cli"来禁用中断并防止触发IRQ, 否则可能会导致内核冲突。为了节省内核空间, 生成较小的二进制文件, 我们让每个ISR的存根(stub)跳转到通用`isr_common_stub`函数。`isr_common_stub`用于将处理器的状态保存到堆栈上, 将当前堆栈地址压入堆栈(为我们的C处理程序提供堆栈), 调用C中的`fault_handler`函数, 最后恢复堆栈的状态。在**"start.asm"**预留的位置中添加下面的代码, 填写所有的32个ISR: 

> start.asm

```assembly
; 在之后的教程中, 我们将添加中断
; 这里是中断服务程序(ISR)
global _isr0
global _isr1
global _isr2
global _isr3
global _isr4
global _isr5
global _isr6
global _isr7
global _isr8
global _isr9
global _isr10
global _isr11
global _isr12
global _isr13
global _isr14
global _isr15
global _isr16
global _isr17
global _isr18
global _isr19
global _isr20
global _isr21
global _isr22
global _isr23
global _isr24
global _isr25
global _isr26
global _isr27
global _isr28
global _isr29
global _isr30
global _isr31

;  0: 除以零异常
_isr0:
    cli
    push byte 0    ; 一个ISR占位符, 会弹出一个为错误码来保持一个统一的堆栈框架
    push byte 0
    jmp isr_common_stub

;  1: 调试异常
_isr1:
    cli
    push byte 0
    push byte 1
    jmp isr_common_stub
    
;  2: 不可屏蔽的中断异常
_isr2:
    cli
    push byte 0
    push byte 2
    jmp isr_common_stub

;  3: Int 3异常
_isr3:
    cli
    push byte 0
    push byte 3
    jmp isr_common_stub

;  4: INTO异常
_isr4:
    cli
    push byte 0
    push byte 4
    jmp isr_common_stub

;  5: 越界异常
_isr5:
    cli
    push byte 0
    push byte 5
    jmp isr_common_stub

;  6: 无效的操作码异常
_isr6:
    cli
    push byte 0
    push byte 6
    jmp isr_common_stub

;  7: 协处理器不可用异常
_isr7:
    cli
    push byte 0
    push byte 7
    jmp isr_common_stub

;  8: 双重故障异常(带错误码！)
_isr8:
    cli
    push byte 8        ; 注意我们不需要在此压入一个值到堆栈中, 它已经压入了一个。
                   ; 会弹出错误码的异常可使用这类存根
    jmp isr_common_stub

;  9: 协处理器段溢出异常
_isr9:
    cli
    push byte 0
    push byte 9
    jmp isr_common_stub

; 10: 错误的TSS异常(带错误码！)
_isr10:
    cli
    push byte 10
    jmp isr_common_stub

; 11: 段不存在异常(带错误码！)
_isr11:
    cli
    push byte 11
    jmp isr_common_stub

; 12: 堆栈故障异常(带错误码！)
_isr12:
    cli
    push byte 12
    jmp isr_common_stub

; 13: 常规保护故障异常(带错误码！)
_isr13:
    cli
    push byte 13
    jmp isr_common_stub

; 14: 页面错误异常(带错误码！)
_isr14:
    cli
    push byte 14
    jmp isr_common_stub

; 15: 保留异常
_isr15:
    cli
    push byte 0
    push byte 15
    jmp isr_common_stub

; 16: 浮点异常
_isr16:
    cli
    push byte 0
    push byte 16
    jmp isr_common_stub

; 17: 对齐检查异常
_isr17:
    cli
    push byte 0
    push byte 17
    jmp isr_common_stub

; 18: 机器检查异常
_isr18:
    cli
    push byte 0
    push byte 18
    jmp isr_common_stub

; 19: 保留
_isr19:
    cli
    push byte 0
    push byte 19
    jmp isr_common_stub

; 20: 保留
_isr20:
    cli
    push byte 0
    push byte 20
    jmp isr_common_stub

; 21: 保留
_isr21:
    cli
    push byte 0
    push byte 21
    jmp isr_common_stub

; 22: 保留
_isr22:
    cli
    push byte 0
    push byte 22
    jmp isr_common_stub

; 23: 保留
_isr23:
    cli
    push byte 0
    push byte 23
    jmp isr_common_stub

; 24: 保留
_isr24:
    cli
    push byte 0
    push byte 24
    jmp isr_common_stub

; 25: 保留
_isr25:
    cli
    push byte 0
    push byte 25
    jmp isr_common_stub

; 26: 保留
_isr26:
    cli
    push byte 0
    push byte 26
    jmp isr_common_stub

; 27: 保留
_isr27:
    cli
    push byte 0
    push byte 27
    jmp isr_common_stub

; 28: 保留
_isr28:
    cli
    push byte 0
    push byte 28
    jmp isr_common_stub

; 29: 保留
_isr29:
    cli
    push byte 0
    push byte 29
    jmp isr_common_stub

; 30: 保留
_isr30:
    cli
    push byte 0
    push byte 30
    jmp isr_common_stub

; 31: 保留
_isr31:
    cli
    push byte 0
    push byte 31
    jmp isr_common_stub

; 我们在这里调用C函数
; 我们需要让汇编器知道"_fault_handler"在另一个文件中
extern _fault_handler

; 这是我们ISR的通用存根
; 它用于保存处理器的状态, 设置内核模式段, 调用C里的故障处理程序
; 最后恢复堆栈框架
isr_common_stub:
    pusha
    push ds
    push es
    push fs
    push gs
    mov ax, 0x10   ; 加载内核数据段描述符
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov eax, esp   ; 将指向堆栈的指针压入堆栈
    push eax
    mov eax, _fault_handler
    call eax       ; 特殊调用, 保存"eip"寄存器的值
    pop eax
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8     ; 清除压入的错误码和ISR号
    iret           ; 将CS、EIP、EFLAGS、SS和ESP一同弹出
```

&emsp;&emsp;创建一个新文件, 命名为**"isrs.c"**。别忘了在**"build.bat"**文件中添加一行GCC命令编译该文件。将文件**"isrs.o"**添加到LD文件列表中,  这样才能将其链接到内核中。**"isrs.c"**文件很简单: 首先是常规的#include行, 声明"start.asm"中每个ISR的原型, 将IDT条目指向正确的ISR, 最后创建一个中断处理程序来服务我们所有的异常。

> isrs.c

```c
#include <system.h>

/* 这里是所有异常处理程序的原型: 
 * IDT的前32个条目由英特尔保留, 
 * 用于处理异常 */
extern void isr0();
extern void isr1();
extern void isr2();
extern void isr3();
extern void isr4();
extern void isr5();
extern void isr6();
extern void isr7();
extern void isr8();
extern void isr9();
extern void isr10();
extern void isr11();
extern void isr12();
extern void isr13();
extern void isr14();
extern void isr15();
extern void isr16();
extern void isr17();
extern void isr18();
extern void isr19();
extern void isr20();
extern void isr21();
extern void isr22();
extern void isr23();
extern void isr24();
extern void isr25();
extern void isr26();
extern void isr27();
extern void isr28();
extern void isr29();
extern void isr30();
extern void isr31();

/* 我们将IDT的前32个条目设置为前32个ISR
 * 这里我们无法使用for循环, 因为无法获取与之对应的函数名
 * 我们将访问标志设置为0x8E, 代表条目存在, 并在Ring 0(内核级别)中运行 
 * 并将低5位设置为要求的"14", 用十六进制的"E"表示 */
void isrs_install()
{
    idt_set_gate(0, (unsigned)isr0, 0x08, 0x8E);
    idt_set_gate(1, (unsigned)isr1, 0x08, 0x8E);
    idt_set_gate(2, (unsigned)isr2, 0x08, 0x8E);
    idt_set_gate(3, (unsigned)isr3, 0x08, 0x8E);
    idt_set_gate(4, (unsigned)isr4, 0x08, 0x8E);
    idt_set_gate(5, (unsigned)isr5, 0x08, 0x8E);
    idt_set_gate(6, (unsigned)isr6, 0x08, 0x8E);
    idt_set_gate(7, (unsigned)isr7, 0x08, 0x8E);

    idt_set_gate(8, (unsigned)isr8, 0x08, 0x8E);
    idt_set_gate(9, (unsigned)isr9, 0x08, 0x8E);
    idt_set_gate(10, (unsigned)isr10, 0x08, 0x8E);
    idt_set_gate(11, (unsigned)isr11, 0x08, 0x8E);
    idt_set_gate(12, (unsigned)isr12, 0x08, 0x8E);
    idt_set_gate(13, (unsigned)isr13, 0x08, 0x8E);
    idt_set_gate(14, (unsigned)isr14, 0x08, 0x8E);
    idt_set_gate(15, (unsigned)isr15, 0x08, 0x8E);

    idt_set_gate(16, (unsigned)isr16, 0x08, 0x8E);
    idt_set_gate(17, (unsigned)isr17, 0x08, 0x8E);
    idt_set_gate(18, (unsigned)isr18, 0x08, 0x8E);
    idt_set_gate(19, (unsigned)isr19, 0x08, 0x8E);
    idt_set_gate(20, (unsigned)isr20, 0x08, 0x8E);
    idt_set_gate(21, (unsigned)isr21, 0x08, 0x8E);
    idt_set_gate(22, (unsigned)isr22, 0x08, 0x8E);
    idt_set_gate(23, (unsigned)isr23, 0x08, 0x8E);

    idt_set_gate(24, (unsigned)isr24, 0x08, 0x8E);
    idt_set_gate(25, (unsigned)isr25, 0x08, 0x8E);
    idt_set_gate(26, (unsigned)isr26, 0x08, 0x8E);
    idt_set_gate(27, (unsigned)isr27, 0x08, 0x8E);
    idt_set_gate(28, (unsigned)isr28, 0x08, 0x8E);
    idt_set_gate(29, (unsigned)isr29, 0x08, 0x8E);
    idt_set_gate(30, (unsigned)isr30, 0x08, 0x8E);
    idt_set_gate(31, (unsigned)isr31, 0x08, 0x8E);
}

/* 这里是一个简单的字符串数组, 包含与每个异常对应的消息
 * 我们通过这种方式来获得对应的消息: 
 * exception_message[interrupt_number] */
unsigned char *exception_messages[] =
{
    "Division By Zero",
    "Debug",
    "Non Maskable Interrupt",
    "Breakpoint",
    "Into Detected Overflow",
    "Out of Bounds",
    "Invalid Opcode",
    "No Coprocessor",

    "Double Fault",
    "Coprocessor Segment Overrun",
    "Bad TSS",
    "Segment Not Present",
    "Stack Fault",
    "General Protection Fault",
    "Page Fault",
    "Unknown Interrupt",

    "Coprocessor Fault",
    "Alignment Check",
    "Machine Check",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",

    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved",
    "Reserved"
};

/* 我们所有的异常处理中断服务程序都将指向此函数, 这会告诉我们发生了什么异常
 * 现在我们只是通过死循环来暂停系统
 * 当所有ISR被用作“锁定”机制时，它们会禁用中断，以防止IRQ的发生并破坏内核数据结构 */
void fault_handler(struct regs *r)
{
    /* 判断是否是中断号为0~31的错误 */
    if (r->int_no < 32)
    {
        /* 显示发生的异常的描述
         * 本教程中我们简单地使用一个死循环来暂停系统 */
        puts(exception_messages[r->int_no]);
        puts(" Exception. System Halted!\n");
        for (;;);
    }
}
```

&emsp;&emsp;等一下, 在`fault_handler`函数的参数中有一个新的结构体`struct regs`我们还没有定义。`regs`向C代码展示了堆栈的框架结构。还记得吗, 我们在"start.asm"中我们将指向堆栈本身的指针压入堆栈, 这样我们就可以从处理程序中获取错误码和中断号。这种设计方式让我们能使用一个C程序来处理不同的ISR, 并可以确定发生的是哪个异常或中断。

&emsp;&emsp;在**"system.h"**中定义堆栈框架: 

> system.h

```c
/* 这定义了ISR运行后的堆栈结构 */
struct regs
{
    unsigned int gs, fs, es, ds;      /* 这些段最后压入 */
    unsigned int edi, esi, ebp, esp, ebx, edx, ecx, eax;  /* 通过"pusha"压入栈中 */
    unsigned int int_no, err_code;
    unsigned int eip, cs, eflags, useresp, ss;   /* 由处理器自动压入堆栈 */ 
};
```

&emsp;&emsp;打开**"system.h"**文件, 添加`reg`结构体的定义和`isrs_install`函数原型, 以便我们在"main.c"中调用。最后, 在`main`函数中安装IDT的后面调用`isrs_install`。现在可以在我们新的内核中测试一下我们的异常处理程序了。

&emsp;&emsp;可选操作: 在**"main.c"**中添加一些测试代码, 该代码进行除以0操作。当处理器遇到该错误, 将会产生"Divide By Zero"异常, 并在屏幕上打印。测试成功后, 你可以删除这些测试代码。