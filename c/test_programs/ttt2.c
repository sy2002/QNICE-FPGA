#ifdef __QNICE__
#define getchar(x) ((fp)2)(x)
#define putchar(x) ((fp)4)(x)
#define gets(x) ((fp)6)(x)
#define putsnl(x) ((fp)8)(x)
#define mult(x,y) ((fp)0xe)(x,y)
#define gethex(x) ((fp)0x24)(x)
#define puthex(x) ((fp)0x26)(x)
#define exit(x) ((fp)0x16)(x)


typedef int (*fp)();

static void puts(char *p)
{
  putsnl(p);
  putsnl("\n\r");
}

#define question putsnl

void putkey(char key)
{
    char output[2] = {0, 0};
    output [0] = key;
    putsnl(&output);
}

#else

#define question puts
#define putkey ;

#endif

int f[4][4];
int bi,bj;

main()
{
    putsnl("Tic-Tac-Toe for QNICE by Volker Barthelmann in September 2016\r\n");

    int i,j,w,amzug,zug;
    char key=0;

    for(i=0;i<3;++i)
        for(j=0;j<3;j++)
            f[i][j]=0;        

    question("May I begin and have the first turn (y/n)? ");
    while(key!='y'&&key!='n')
      key=getchar();
    putkey(key);
    if(key=='y') amzug=1; else amzug=0;
    puts("");

    zug=0;printfield();

    while(1){
        bi=bj=4;
        if(w=win()){
            if(w>0){
              puts("I won!");
              exit(0);
            }else{
              puts("You won - this is impossible!");
              exit(0);
            }
        }
        zug++;
        if(zug>9){
           puts("Nobody wins - draw!");
           exit(0);
        }
        if(amzug){
            if(zug>1) w=rek(0); else {w=0;bi=bj=1;}
            f[bi][bj]=1;
            if(w&&zug<9) puts("I will win...");
        }else{
            while(bi<1||bi>3||bj<1||bj>3||f[bi-1][bj-1]){
                question("Your turn (x,y): ");
                bj=bi=0;
                while(bj<'1'||bj>'3')
                    bj=getchar();
                putkey(bj);
                while(bi<'1'||bi>'3')
                    bi=getchar();
                putkey(bi);
                bi-='0';bj-='0';
                puts("");
            }
            f[bi-1][bj-1]=-1;
        }
        printfield();
        amzug=1-amzug;
    }
}
rek(t)
    int t;
{
    int i,j,z,bw,w,s;
    z=0;
    w=win();
    if(w!=0) return(w);
    if(t&1) s=-1; else s=1;
    bw=-s;
    for(i=0;i<3;i++){
        for(j=0;j<3;j++){
            if(f[i][j]==0){
                z=1; f[i][j]=s;
                w=rek(t+1);
                if((w>=bw&&s==1)||(w<=bw&&s==-1)){
                    bw=w;
                    if(t==0) {bi=i;bj=j;}
                    if(bw==s) {f[i][j]=0;return(bw);}
                }
                f[i][j]=0;
            }
        }
    }
    if(z==0) {bw=win();}
    return(bw);
}

int win()
{
    int i;
    for(i=0;i<3;i++){
        if(f[i][0]==1&&f[i][1]==1&&f[i][2]==1) return(1);
        if(f[i][0]==-1&&f[i][1]==-1&&f[i][2]==-1) return(-1);
        if(f[0][i]==1&&f[1][i]==1&&f[2][i]==1) return(1);
        if(f[0][i]==-1&&f[1][i]==-1&&f[2][i]==-1) return(-1);
    }
    if(f[0][0]==1&&f[1][1]==1&&f[2][2]==1) return(1);
    if(f[0][0]==-1&&f[1][1]==-1&&f[2][2]==-1) return(-1);
    if(f[0][2]==1&&f[1][1]==1&&f[2][0]==1) return(1);
    if(f[0][2]==-1&&f[1][1]==-1&&f[2][0]==-1) return(-1);
    return(0);
}
printfield()
{
    static char field[]={'O',' ','X'};
    int i,j;
    for(i=0;i<3;++i){
        putchar('1'+i);
        for(j=0;j<3;j++){
            putchar('|');
            putchar(field[f[i][j]+1]);
        }
        puts("|");
        puts(" -------");
    }
    puts("  1 2 3");

}
