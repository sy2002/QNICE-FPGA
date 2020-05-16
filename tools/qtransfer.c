#include <errno.h>
#include <fcntl.h> 
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

int set_interface_attribs (int fd, int speed, int parity)
{
        struct termios tty;
        if (tcgetattr (fd, &tty) != 0)
        {
                printf("Error %d from tcgetattr\n", errno);
                return -1;
        }

        cfsetospeed (&tty, speed);
        cfsetispeed (&tty, speed);

        tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8;     // 8-bit chars
        // disable IGNBRK for mismatched speed tests; otherwise receive break
        // as \000 chars
        tty.c_iflag &= ~IGNBRK;         // disable break processing
        tty.c_lflag = 0;                // no signaling chars, no echo,
                                        // no canonical processing
        tty.c_oflag = 0;                // no remapping, no delays
        tty.c_cc[VMIN]  = 0;            // read doesn't block
        tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

        tty.c_iflag &= ~(IXON | IXOFF | IXANY); // shut off xon/xoff ctrl

        tty.c_cflag |= (CLOCAL | CREAD);// ignore modem controls,
                                        // enable reading
        tty.c_cflag &= ~(PARENB | PARODD);      // shut off parity
        tty.c_cflag |= parity;
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;

        if (tcsetattr (fd, TCSANOW, &tty) != 0)
        {
                printf("Error %d from tcsetattr\n", errno);
                return -1;
        }
        return 0;
}

void set_blocking (int fd, int should_block)
{
        struct termios tty;
        memset (&tty, 0, sizeof tty);
        if (tcgetattr (fd, &tty) != 0)
        {
                printf("Error %d from tggetattr\n", errno);
                return;
        }

        tty.c_cc[VMIN]  = should_block ? 1 : 0;
        tty.c_cc[VTIME] = 5;            // 0.5 seconds read timeout

        if (tcsetattr (fd, TCSANOW, &tty) != 0)
                printf("Error %d setting term attributes", errno);
}

uint16_t calc_crc(char* buffer, unsigned int size)
{
    const uint16_t mask = 0xA001;
    uint16_t crc = 0xFFFF;
    int i = 0;
    while (i < size)
    {
        crc ^= *buffer;
        crc = (crc & 1) ? (crc >> 1) ^ mask : crc >> 1;
        buffer++;        
        i++;
    }
    return crc;
}

int main(int argc, char* argv[])
{
    char* portname;
    FILE* inputf;
    char buf[100];
    char response[100];

    if (argc < 3 || (inputf = fopen(argv[1], "r")) == 0)
    {
        printf("qtransfer <filename> <portname>\n");
        return 1;
    }

    fseek(inputf, 0L, SEEK_END);
    unsigned long file_lines = ftell(inputf) / 14;
    if (ftell(inputf) % 14 != 0)
    {
        printf("Error: Input file %s seems to be corrupt.\n", argv[1]);
        return 1;
    }
    rewind(inputf);

    portname = argv[2];
    int fd = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0)
    {
            printf("Error %d opening %s: %s\n", errno, portname, strerror (errno));
            return 1;
    }

    set_interface_attribs (fd, B115200, 0);  // set speed to 115,200 bps, 8n1 (no parity)
    set_blocking (fd, 0);                    // set no blocking

    //initial handshake: send "START\n" and receive a zero terminated "ACK"
    write (fd, "START\n", 6);
    usleep (20 * 100);
    int n = read(fd, buf, sizeof(buf));
    if (n != 4 || strcmp(buf, "ACK") != 0)
    {
        printf("Protocol error. (Are you running qtransfer.asm on QNICE?)\n");
        return 1;
    }

    char line[100];
    unsigned long lines_done = 0;
    while (1)
    {
        fgets(line, sizeof(line), inputf);
        if (feof(inputf))
            break;

        //build transmit string: <address><data><crc>\n
        memset(buf, 0, sizeof(buf));
        strncpy(&buf[0], &line[2], 4);
        strncpy(&buf[4], &line[9], 4);
        sprintf(&buf[8], "%04hX", calc_crc(buf, 8));
        buf[12] = '\n';

        //send
        write(fd, buf, 13);
        usleep(2 * 100);

        //receive answer (or fill up the buffer on QNICE side with '\n')
        int fill = 0;
        while ((n = read(fd, response, sizeof(response))) == 0)
        {
            usleep(2 * 100);
            write(fd, &buf[12], 1);
            usleep(10 * 100);
            if (fill++ > 13)
            {
                printf("Error transmitting to QNICE.\n");
                return 1;
            }
        }

        //everything worked: next line of .out file
        if (n == 4 && strcmp(response, "ACK") == 0)
        {
            lines_done++;
            printf("%lu of %lu done.\n", lines_done, file_lines);
            continue;
        }

        //CRC error
        else if (n == 7 && strcmp(response, "CRCERR") == 0)
        {
            printf("CRC Error! %s\n", buf);
            return 1;
        }
    }

    write(fd, "END\n", 4);
    usleep(100 * 100);

    fclose(inputf);
    close(fd);

/*
    usleep ((7 + 25) * 100);             // sleep enough to transmit the 7 plus
                                         // receive 25:  approx 100 uS per char transmit
    char buf [100];
    int n = read (fd, buf, sizeof buf);  // read up to 100 characters if ready to read
*/
    return 0;
}
