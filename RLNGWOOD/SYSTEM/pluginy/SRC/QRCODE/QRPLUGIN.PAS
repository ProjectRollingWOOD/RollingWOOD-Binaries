program qrplugin;

uses Objects,Dos,DelphiZXIngQRCode;

type
BMP_header = packed record
{00}         magic:word;
{02}         sizebmp:longint;
{06}         reserved:longint;
{10}         offset_to_data:longint;
{14}         header_size:longint;
{18}         width:longint;
{22}         height:longint;
{26}         numplanes:word;
{28}         bits_per_pixel:word;
{30}         compressed:longint;
{34}         sizeimage:longint;
{38}         xres:longint;
{42}         yres:longint;
{46}         clrused:longint;
{50}         clrimportant:longint;{ve Windows je pouzito pro rotaci barev }
             end;                 {pri zobrazovani animovaneho loga. Pokud=0,}
                                  {tak jsou vsechny barvy staticke. pokud=1,}
                                  {je staticka jenom 0, pokud=2, jsou staticke}
                                  {0 a 1 a ostatni se cykli, atd...}


var predany_buffer:pchar;


function MyVal(s:string):longint;
var i,j:longint;
begin
Val(s,i,j);
MyVal:=i;
end;


Function KontrolaPredanychParametru(var segm,ofse:longint):boolean;
var k,l,m:longint;
    s,par:string;
    dpar,bpar:string;
    c,d:char;
    veslove:boolean;

begin

{for k:=1 to Envcount do writeln(envstr(k));
readln;}

s:=GetEnv('VENOMLINK');
if s='' then
   begin
   writeln('This program is not a standalone application but plugin for Blocek.');
   Exit(false);
   end;

dpar:='';
bpar:='';
veslove:=false;
s:=s+' ';
segm:=0;
ofse:=0;
for k:=1 to Length(s) do
    begin
    c:=s[k];
    if c<>' ' then
       if veslove=false then
          begin
          veslove:=true;
          l:=k;
          end else
       else   {tzn. c=' '}
       if veslove=true then
          begin
          veslove:=false;
          par:=Copy(s,l,k-l);
          d:=UpCase(par[1]);
          m:=MyVal(Copy(par,2,255));
          if d='D' then
             if m<>0 then segm:=m else Exit(false) else

          if d='B' then
             if m<>0 then ofse:=m else Exit(false);
          end;

    end;

if (segm=0) or (ofse=0) then Exit(false);
KontrolaPredanychParametru:=true;
end;


Function Zjisti_delku_predavaneho_bloku(segm,ofse:longint):longint;
var i:longint;
begin
asm
push es
mov eax,segm
mov es,ax
mov ebx,ofse
mov ecx,es:[ebx]
mov i,ecx
pop es
end;
Zjisti_delku_predavaneho_bloku:=i;
end;


Procedure Nacti_data_z_predavaneho_bloku(segm,ofse,vel_bloku:longint;predavany_blok:pchar);
begin
asm
push es
push edi
mov eax,segm
mov es,ax
mov ebx,ofse
mov ecx,vel_bloku
mov edi,predavany_blok

@smycka:
mov al,es:[ebx]
mov ds:[edi],al
inc ebx
inc edi
Loop @smycka

pop edi
pop es
end;
end;


Procedure Zapis_data_do_bloku_pro_zapis(segm,vofse:longint;hotove_bmp:pointer;v:longint);
begin
asm
push es
push edi
mov eax,segm
mov es,ax
mov ebx,vofse

mov ecx,v
mov es:[ebx],ecx   {zapsali jsme delku}
add ebx,4          {posun na dalsi pozici}


jecxz @nic_nedelej  {co kdyz neni nic k zapsani?}

mov edi,hotove_bmp

@smycka:
mov al,ds:[edi]
mov es:[ebx],al
inc edi
inc ebx
Loop @smycka

@nic_nedelej:

pop edi
pop es
end;
end;


Function QR_2_BMP(q:TDelphiZXingQRCode;vc:longint;var hotove_bmp:pchar;var hbv:longint):boolean;
var h:BMP_header;
    o:longint;
    isb:boolean;
{    v_breiteminus1:longint;}
    r,g,b:byte;
    t:word;
    i,bx,j,jj,k,l,n:dword;
    x:PChar;
    f:{PBufStream;}PMemoryStream;
    z:File;
    inverze:boolean;

begin
inverze:=false;

f:=New(PMemoryStream,Init($10000,$1000));
if f^.ErrorInfo<>0 then
   begin
   Dispose(f,Done);
   hotove_bmp:=nil;
   hbv:=0;
   Exit(false);
   end;
h.magic:=$4d42;   {BM}
h.sizebmp:=SizeOf(BMP_header)+(q.columns*q.rows*3*vc*vc);
h.reserved:=0;
h.offset_to_data:=SizeOf(BMP_header);
h.header_size:=40;
h.width:=q.columns*vc;
h.height:=q.rows*vc;
h.numplanes:=1;
h.bits_per_pixel:=24;
h.compressed:=0;
h.sizeimage:=0;
h.xres:=0;
h.yres:=0;
h.clrused:=0;
h.clrimportant:=0;
k:=q.columns*vc;
j:=k mod 4;
k:=k*3;
{v_breiteminus1:=q.columns-1;}
if j<>0 then inc(k,j);
GetMem(x,k);
f^.Write(h,SizeOf(BMP_header));
for j:=q.rows-1 downto 0 do
    for jj:=1 to vc do
        begin
        l:=0;
        for i:=0 to q.columns-1 do
            begin
            isb:=Q.IsBlack[j, i] xor inverze;
            if isb then
               begin
               r:=0;
               g:=0;
               b:=0;
               end
               else begin
               r:=255;
               g:=255;
               b:=255;
               end;

            for n:=1 to vc do
                begin
                x[l+0]:=char(b);
                x[l+1]:=char(g);
                x[l+2]:=char(r);
                inc(l,3);
                end;
            end;
        f^.Write(x^,k);  {ulozi radku}
        end;

FreeMem(x,k);

hbv:=f^.GetSize;
GetMem(hotove_bmp,hbv);
f^.Seek(0);
f^.Read(hotove_bmp^,hbv);
Dispose(f,Done);
QR_2_BMP:=true;
end;


Procedure QR_2_1pole(q:TDelphiZXingQRCode;var hotove_pole:pchar;var hbv:longint);
var i,j,a:longint;
    d1,d2:^longint;
begin
a:=0;
hbv:=q.rows*q.columns+8;
GetMem(hotove_pole,hbv);  {4 bajty sirka, 4 bajty vyska, pak pole}

d1:=@hotove_pole[0];
d1^:=q.columns;
d2:=@hotove_pole[4];
d2^:=q.rows;
a:=8;
for j:=0 to q.rows-1 do
    for i:=0 to q.columns-1 do
        begin
        hotove_pole[a]:=char(byte(Q.IsBlack[j, i]));
        inc(a);
        end;
end;



Procedure Prevod_do_QR(ped:pchar;dp,vct:longint;var hotove_bmp:pointer;var hbm:longint);
var qr:TDelphiZXingQRCode;
    x,y:longint;
    uu:pwidechar;
    uniqrt:widestring;

begin
uu:=pointer(ped);
uniqrt:=uu;
qr:=TDelphiZXingQRCode.Create;
qr.data:=uniqrt;
qr.encoding:=qrUTF8BOM;  {mozna by slo zmenit na <qrUTF8noBOM>}
qr.quietzone:=1;

QR_2_1pole(qr,hotove_bmp,hbm);

{QR_2_BMP(qr,vct,hotove_bmp,hbm);}

QR.Free;
end;


var s:string;
    segm,ofse:longint;
    delka_bloku,hbm:longint;
    vel_ct:^longint;
    delka_ped:^longint;
    vyst_ofse:^longint;
    predavany_blok:pchar;
    ped:pchar;
    hotove_bmp:pchar;

begin
if not KontrolaPredanychParametru(segm,ofse) then Halt(255);

delka_bloku:=Zjisti_delku_predavaneho_bloku(segm,ofse);
if delka_bloku<=0 then Halt(254);
GetMem(predavany_blok,delka_bloku);
Nacti_data_z_predavaneho_bloku(segm,ofse,delka_bloku,predavany_blok);


ped:=pointer(@predavany_blok[20]);
delka_ped:=@predavany_blok[16];
vyst_ofse:=@predavany_blok[12];
vel_ct:=@predavany_blok[8];

hbm:=0;
Prevod_do_QR(ped,delka_ped^,vel_ct^,hotove_bmp,hbm);

{writeln(hbm);
writeln(hotove_bmp[0]);
writeln(hotove_bmp[1]);
readln;}

Zapis_data_do_bloku_pro_zapis(segm,vyst_ofse^,hotove_bmp,hbm);

FreeMem(predavany_blok);
FreeMem(hotove_bmp)
end.
