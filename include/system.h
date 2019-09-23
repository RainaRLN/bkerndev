#ifndef __SYSTEM_H
#define __SYSTEM_H

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

#endif

