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

