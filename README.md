# Info
Since the program uses direct access to sectors
hard disk, you need to execute it in the operating environment of a real
mode, i.e. 16-bit. The utility has a number of restrictions and requirements,
the result of non-execution of which is unpredictable. All responsibility for
misuse of the program the user assumes.<br/>
Development, debugging and testing of the utility were carried out in the OS
MSDOS using the TASM software package.
## General operation of the program
The launch is done using the command line.<br/>
After starting the program, the user is prompted to enter the full
the path to the directory in which to search for the file.<br/>
After reading the entered path, the program checks the letter of the root
directory that duplicates the logical drive letter. In case of error
an appropriate message is displayed about an incorrectly entered letter.<br/>
Then the number of entered directories is checked and
filling in an array of names, if the number of directories exceeds 6, then
the program terminates without outputting a message.<br/>
The next step is to check if the boot sector is read.
logical drive. In case of a reading error, the corresponding
message.<br/>
After successfully loading the boot sector into the buffer, the file
systems, if it is not FAT16, then an error message is displayed and the program
is interrupted.<br/>
After performing basic requirements checks, the program reads from
boot sector cluster size, number of reserved
sectors, root directory size, FAT table size.<br/>
Then the root directory sector is calculated and searched for
the first directory entered, with its cluster number written into memory. After
this calculates the sector of the first directory and checks for
following directories in the entered path. If there are directories other than
First, the program determines their numbers of clusters and sectors. In the last
directory, a search is made for the file (including the directory) with the "longest"
name. The found name is displayed on the screen. If there are no files in the directory,
an appropriate message is displayed.<br/>
