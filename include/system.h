#ifndef __SYSTEM_H
#define __SYSTEM_H

/* 这定义了ISR运行后的堆栈结构 */
struct regs
{
    unsigned int gs, fs, es, ds;      /* 这些段最后压入 */
    unsigned int edi, esi, ebp, esp, ebx, edx, ecx, eax;  /* 通过"pusha"压入栈中 */
    unsigned int int_no, err_code;
    unsigned int eip, cs, eflags, useresp, ss;   /* 由处理器自动压入堆栈 */ 
};

/* main.c */
extern void *memcpy(void *dest, const void *src, int count);
extern void *memset(void *dest, unsigned char val, int count);
extern unsigned short *memsetw(unsigned short *dest, unsigned short val, int count);
extern int strlen(const char *str);
extern unsigned char inportb (unsigned short _port);
extern void outportb (unsigned short _port, unsigned char _data);

/* scrn.c */
extern void cls();
extern void putch(char c);
extern void puts(char *str);
extern void settextcolor(char forecolor, char backcolor);
extern void init_video();

/* gdt.c */
extern void gdt_set_gate(int num, unsigned long base, unsigned long limit, unsigned char access, unsigned char gran);
extern void gdt_install();

/* idt.c */
extern void idt_set_gate(unsigned char num, unsigned long base, unsigned short sel, unsigned char flags);
extern void idt_install();

/* isrs.c */
extern void isrs_install();

#endif

