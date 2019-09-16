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
