echo "Now assembling, compiling, and linking your kernel:"
nasm -f elf64 -o start.o start.asm
# Remember this spot here: We will add 'gcc' commands here to compile C sources

# This links all your files. Remember that as you add *.o files, you need to
# add them after start.o. If you don't add them at all, they won't be in your kernel!
ld -T link.ld -o kernel.bin start.o
echo "Done!"
read -p "Press a key to continue..."
