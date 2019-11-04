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


; BSS区的定义
; 现在问将用它来存储栈
; 栈是向下生长的，所以我们在声明'_sys_stack'
SECTION .bss
    resb 8192               ; 保留8KB内存
_sys_stack:
