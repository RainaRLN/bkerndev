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

/* 使用该函数来设置每项IDT*/
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
