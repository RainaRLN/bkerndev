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

stublet:
    extern main
    call main
    jmp $


; GDT加载代码
; 这将建立我们新的段寄存器
; 通过长跳转来设置CS
global gdt_flush     ; 允许C源程序链接该函数
extern gp            ; 声明_gp为外部变量
gdt_flush:
    lgdt [gp]        ; 用_gp来加载GDT
    mov ax, 0x10      ; 0x10是我们数据段在GDT中的偏移地址
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    jmp 0x08:flush2   ; 0x08是代码段的偏移地址, 长跳转
flush2:
    ret               ; 返回到C程序中
    
; 加载idtp指针所指的IDT到处理器中
; 这在C文件中声明为"extern void idt_load();"
global idt_load
extern idtp
idt_load:
    lidt [idtp]
    ret

; ISR代码
; 在之后的教程中, 我们将添加中断
; 这里是中断服务程序(ISR)
global isr0
global isr1
global isr2
global isr3
global isr4
global isr5
global isr6
global isr7
global isr8
global isr9
global isr10
global isr11
global isr12
global isr13
global isr14
global isr15
global isr16
global isr17
global isr18
global isr19
global isr20
global isr21
global isr22
global isr23
global isr24
global isr25
global isr26
global isr27
global isr28
global isr29
global isr30
global isr31

;  0: 除以零异常
isr0:
    cli
    push byte 0    ; 一个ISR占位符, 会弹出一个为错误码来保持一个统一的堆栈框架
    push byte 0
    jmp isr_common_stub

;  1: 调试异常
isr1:
    cli
    push byte 0
    push byte 1
    jmp isr_common_stub
    
;  2: 不可屏蔽的中断异常
isr2:
    cli
    push byte 0
    push byte 2
    jmp isr_common_stub

;  3: Int 3异常
isr3:
    cli
    push byte 0
    push byte 3
    jmp isr_common_stub

;  4: INTO异常
isr4:
    cli
    push byte 0
    push byte 4
    jmp isr_common_stub

;  5: 越界异常
isr5:
    cli
    push byte 0
    push byte 5
    jmp isr_common_stub

;  6: 无效的操作码异常
isr6:
    cli
    push byte 0
    push byte 6
    jmp isr_common_stub

;  7: 协处理器不可用异常
isr7:
    cli
    push byte 0
    push byte 7
    jmp isr_common_stub

;  8: 双重故障异常(带错误码！)
isr8:
    cli
    push byte 8        ; 注意我们不需要在此压入一个值到堆栈中, 它已经压入了一个。
                   ; 会弹出错误码的异常可使用这类存根
    jmp isr_common_stub

;  9: 协处理器段溢出异常
isr9:
    cli
    push byte 0
    push byte 9
    jmp isr_common_stub

; 10: 错误的TSS异常(带错误码！)
isr10:
    cli
    push byte 10
    jmp isr_common_stub

; 11: 段不存在异常(带错误码！)
isr11:
    cli
    push byte 11
    jmp isr_common_stub

; 12: 堆栈故障异常(带错误码！)
isr12:
    cli
    push byte 12
    jmp isr_common_stub

; 13: 常规保护故障异常(带错误码！)
isr13:
    cli
    push byte 13
    jmp isr_common_stub

; 14: 页面错误异常(带错误码！)
isr14:
    cli
    push byte 14
    jmp isr_common_stub

; 15: 保留异常
isr15:
    cli
    push byte 0
    push byte 15
    jmp isr_common_stub

; 16: 浮点异常
isr16:
    cli
    push byte 0
    push byte 16
    jmp isr_common_stub

; 17: 对齐检查异常
isr17:
    cli
    push byte 0
    push byte 17
    jmp isr_common_stub

; 18: 机器检查异常
isr18:
    cli
    push byte 0
    push byte 18
    jmp isr_common_stub

; 19: 保留
isr19:
    cli
    push byte 0
    push byte 19
    jmp isr_common_stub

; 20: 保留
isr20:
    cli
    push byte 0
    push byte 20
    jmp isr_common_stub

; 21: 保留
isr21:
    cli
    push byte 0
    push byte 21
    jmp isr_common_stub

; 22: 保留
isr22:
    cli
    push byte 0
    push byte 22
    jmp isr_common_stub

; 23: 保留
isr23:
    cli
    push byte 0
    push byte 23
    jmp isr_common_stub

; 24: 保留
isr24:
    cli
    push byte 0
    push byte 24
    jmp isr_common_stub

; 25: 保留
isr25:
    cli
    push byte 0
    push byte 25
    jmp isr_common_stub

; 26: 保留
isr26:
    cli
    push byte 0
    push byte 26
    jmp isr_common_stub

; 27: 保留
isr27:
    cli
    push byte 0
    push byte 27
    jmp isr_common_stub

; 28: 保留
isr28:
    cli
    push byte 0
    push byte 28
    jmp isr_common_stub

; 29: 保留
isr29:
    cli
    push byte 0
    push byte 29
    jmp isr_common_stub

; 30: 保留
isr30:
    cli
    push byte 0
    push byte 30
    jmp isr_common_stub

; 31: 保留
isr31:
    cli
    push byte 0
    push byte 31
    jmp isr_common_stub

; 我们在这里调用C函数
; 我们需要让汇编器知道"fault_handler"在另一个文件中
extern fault_handler

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
    mov eax, fault_handler
    call eax       ; 特殊调用, 保存"eip"寄存器的值
    pop eax
    pop gs
    pop fs
    pop es
    pop ds
    popa
    add esp, 8     ; 清除压入的错误码和ISR号
    iret           ; 将CS、EIP、EFLAGS、SS和ESP一同弹出

; BSS区的定义
; 现在问将用它来存储栈
; 栈是向下生长的，所以我们在声明'_sys_stack'
SECTION .bss
    resb 8192               ; 保留8KB内存
_sys_stack:
