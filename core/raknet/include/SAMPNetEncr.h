/*
	Updated to 0.3.7 by P3ti
*/

extern unsigned char encrBuffer[4092];
extern unsigned char decrBuffer[4092];

void kyretardizeDatagram(unsigned char *buf, int len, int port, int unk);
void unKyretardizeDatagram(unsigned char *buf, int len, int port, int unk);