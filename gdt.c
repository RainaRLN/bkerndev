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
