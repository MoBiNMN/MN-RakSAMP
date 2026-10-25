/*
	Updated to 0.3.7 by P3ti
*/

extern thread_local unsigned char encrBuffer[4092];
extern thread_local unsigned char decrBuffer[4092];

void kyretardizeDatagram(unsigned char *buf, int len, int port, int unk);
void unKyretardizeDatagram(unsigned char *buf, int len, int port, int unk);
