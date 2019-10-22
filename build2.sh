echo "Now assembling, compiling, and linking your kernel:"
nasm -f elf -g -F stabs -o start.o start.asm
# Remember this spot here: We will add 'gcc' commands here to compile C sources
gcc -Wall -fno-pic -m32 -ggdb -gstabs+ -nostdinc -fno-builtin -fno-stack-protector -I./include -c -o main.o main.c
gcc -Wall -fno-pic -m32 -ggdb -gstabs+ -nostdinc -fno-builtin -fno-stack-protector -I./include -c -o scrn.o scrn.c
gcc -Wall -fno-pic -m32 -ggdb -gstabs+ -nostdinc -fno-builtin -fno-stack-protector -I./include -c -o gdt.o gdt.c

# This links all your files. Remember that as you add *.o files, you need to
# add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -m elf_i386 -nostdlib -o kernel.bin start.o main.o scrn.o gdt.o
echo "Done!"
read -p "Press a key to continue..."
