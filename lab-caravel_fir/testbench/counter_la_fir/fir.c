#include "fir.h"
#include <defs.h>

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	tap0 = taps[0];
	tap1 = taps[1];
	tap2 = taps[2];
	tap3 = taps[3];
	tap4 = taps[4];
	tap5 = taps[5];
	tap6 = taps[6];
	tap7 = taps[7];
	tap8 = taps[8];
	tap9 = taps[9];
	tap10 = taps[10];
	
	datalength = 64;
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	initfir();
	//write down your fir
	
	reg_mprj_datal = 0x00A50000;
	apcontrol = 0x00000001;
	
	int x[64];
	for(int i = 0 ; i < datalength ; i++)
		x[i] = i;
	
	int read_ap = apcontrol;
	for(int i = 0 ; i < datalength ; i++){
		while(i>0 && !((read_ap)>>4 & 1) )
			read_ap = apcontrol;
		
		Xn = x[i];
		
		while( !((read_ap)>>5 & 1) ){
			read_ap = apcontrol;
		}
		
		ans[i] = Yn;
		
	}
	read_ap = apcontrol;
	
	reg_mprj_datal = (ans[63] << 24) | 0x005A0000 ;
	
	
	return ans;
}
		
