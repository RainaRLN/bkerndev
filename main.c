#include <system.h>

void *memcpy(void *dest, const void *src, int count)
{
    const unsigned char *sp = (const unsigned char *)src;
    unsigned char *dp = dest;
    for(; count != 0; count--) *dp++ = *sp++;
    return dest;
}

void *memset(void *dest, unsigned char val, int count)
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
int main()
{
    // int i;
    
    gdt_install();
    idt_install();
    init_video();
    puts("Hello World!\n");

    // i = 10 / 0;
    // putch(i);

    /* 保留此循环
    *  不过, 在'start.asm'里也有一个无限循环, 防止你不小心删除了下面这一行*/
    for (;;);
    return 0;
}
