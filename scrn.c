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
        /* 1-25行往上平移一行到0-24行 */
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
void putch(char c)
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
void puts(char *text)
{
    int i;

    for (i = 0; i < strlen(text); i++)
    {
        putch(text[i]);
    }
}

/* 设置前景色和背景色 */
void settextcolor(char forecolor, char backcolor)
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
