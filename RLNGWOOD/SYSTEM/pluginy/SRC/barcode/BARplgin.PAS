Program Barplgin;
uses types,fpbarcode,fpimgbarcode, fpimage, fpwritebmp, dos;

{
  BarcodeEncodingNames: array[TBarcodeEncoding] of string =
    (
      '128 A', '128 B', '128 C',
      '2 of 5 industrial', '2 of 5 interleaved', '2 of 5 matrix',
      '39', '39 Extended',
      '93', '93 Extended',
      'Codabar',
      'EAN 13', 'EAN 8',
      'MSI',
      'PostNet'
    );

Function StringAllowsBarEncoding(S : AnsiString; aEncoding : TBarcodeEncoding) : Boolean;
Function StringToBarTypeArray(S : AnsiString; aEncoding : TBarcodeEncoding) : TBarTypeArray;
Function StringToBarcodeParams(S : AnsiString; aEncoding : TBarcodeEncoding) : TBarParamsArray;
Function IntToBarTypeArray(I: Int64; aEncoding : TBarcodeEncoding; aWidth : Integer = 0) : TBarTypeArray;
Function IntToBarcodeParams(I : Int64; aEncoding : TBarcodeEncoding; aWidth : Integer = 0) : TBarParamsArray;
Function BarTypeToBarParams(aType : TBarType) : TBarParams;
Function BarTypeArrayToBarParamsArray(anArray : TBarTypeArray) : TBarParamsArray;
Function CalcBarWidths(aEncoding : TBarcodeEncoding; aUnit : Integer; AWeight : Double) : TBarWidthArray;
Function CalcStringWidthInBarCodeEncoding(S : AnsiString;aEncoding : TBarcodeEncoding; aUnit : Integer; AWeight : Double) : Cardinal;
}


type
TLacBarCode = object
BCclass:TFPDrawBarcode;
{img : TFPcustomImage;}
CanvasWidth,CanvasHeight:longint;
FEncoding:TBarcodeEncoding;
FUnit:Longint;
FWeight:real;
FWidths : TBarWidthArray;
byla_alokace:boolean;
procedure Init;
Procedure CreateBarCode(const txt:string);
Function LzeZakodovat(const txt:string;kodovani:TBarcodeEncoding):boolean;
Function ZjistiNutnouSirku(const txt:string):longint;
Procedure Done;
end;


var bar:TLacBarCode;


function MyVal(s:string):longint;
var i,j:longint;
begin
Val(s,i,j);
MyVal:=i;
end;

function MyStr(i:longint):string;
var s:string;
begin
Str(i,s);
mystr:=s;
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


Procedure Zapis_data_do_bloku_pro_zapis(segm,vofse:longint;adresa_bloku:pointer;delka_bloku:longint);
begin
asm
push es
push edi
mov eax,segm
mov es,ax
mov ebx,vofse

mov ecx,delka_bloku
mov es:[ebx],ecx   {zapsali jsme delku}
add ebx,4          {posun na dalsi pozici}


jecxz @nic_nedelej  {co kdyz neni nic k zapsani?}

mov edi,adresa_bloku

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





Procedure TLacBarCode.Init;
begin

{img:=nil;}
CanvasWidth:=250;
CanvasHeight:=40;
FWeight:=2.0;{4.0;}{1.0};
FUnit:=2;
FEncoding:=beEAN13;
byla_alokace:=false;
end;


Procedure TLacBarCode.CreateBarCode(const txt:string);
begin
BCclass:=TFPDrawBarcode.Create;

BCclass.weight:=FWeight;
BCclass.encoding:=FEncoding;
BCclass.UnitWidth:=FUnit;

BCclass.text:=txt;
CanvasWidth:=BCclass.CalcWidth;

BCclass.rect:=Rect(0,0,CanvasWidth-1,CanvasHeight-1);
BCclass.image:=TFPCompactImgGray16bit.Create(bcclass.rect.width,bcclass.rect.height);
BCclass.Draw;
byla_alokace:=true;


{Img:=TFPCompactImgGray16Bit.Create(FWidth,FHeight);
DrawBarCode(Img,txt,FEncoding,FUnit,FWeight);}
end;


Function TLacBarCode.LzeZakodovat(const txt:string;kodovani:TBarcodeEncoding):boolean;
begin
LzeZakodovat:=StringAllowsBarEncoding(txt,kodovani);
end;


Function TLacBarCode.ZjistiNutnouSirku(const txt:string):longint;
var r:cardinal;
begin

r:=CalcStringWidthInBarCodeEncoding(txt,fEncoding,fUnit,fWeight);
ZjistiNutnouSirku:=round(r);
end;


Procedure TLacBarCode.Done;
begin
if byla_alokace then
   begin
   BCclass.Image.Free;
   BCclass.Free;
   byla_alokace:=false;
   end;
end;


Procedure VygenerujSeznamMoznychKodu(const s:string;var data:pchar;var delka:longint);
var i:longint;
    b:boolean;
    kodovani:TBarcodeEncoding;
    a:ansistring;
    u:string;

begin
a:='';
u:='';
i:=-1;
{a:=MyStr(i)+#13#10;}
for kodovani in TBarcodeEncodings do
    begin
    inc(i);
    if a<>'' then a:=a+#13#10;
    b:=bar.LzeZakodovat(s,kodovani);
    if b=true then begin a:=a+'<num='+mystr(i)+';zakaz=->'+BarcodeEncodingNames[kodovani];u:=u+'+';end
              else begin a:=a+'<num='+mystr(i)+';zakaz=+>'+BarcodeEncodingNames[kodovani];u:=u+'-';end;
    end;

a:=u+#13#10+a;

i:=Length(a);
delka:=i+1;
GetMem(data,delka);
Move(a[1],data[0],i);
data[i]:=#0;
end;


Procedure VygenerujBarKod(s:string;povel:longint;var data:pchar;var delka:longint);
var b:boolean;
    i,n,x,y:longint;
    iw,ih:word;
    iiw,iih:^word;
    c:char;
    kodovani:TBarcodeEncoding;
    barva:tfpcolor;

    myimg:TFPCustomImage;

begin
kodovani:=TBarCodeEncoding(povel-100);
bar.FEncoding:=kodovani;

bar.CreateBarCode(s);     {alokuje canvas a vykresli do nej carovy kod}

myimg:=bar.BCclass.image;

iw:=myimg.width;
ih:=myimg.height;

delka:=longint(iw)*longint(ih)+4;
i:=4;
GetMem(data,delka);
iiw:=@data[0];
iih:=@data[2];
iiw^:=iw;
iih^:=ih;
for y:=0 to ih-1 do
    begin
    for x:=0 to iw-1 do
        begin
        barva:=myimg.colors[x,y];
        if barva.red=0 then c:=#0 else c:=#255;
        c:=char(barva.red);
        data[i]:=c;
        inc(i);
        end;
    end;
end;


var
    segm,ofse:longint;
    delka_bloku,delka_odpovedi:longint;
    povel:^longint;
    delka_ped:^longint;
    vyst_ofse:^longint;
    predavany_blok:pchar;
    ped:pchar;
    hotova_odpoved:pchar;

    s:string;
    b:boolean;
    n:longint;

begin

if not KontrolaPredanychParametru(segm,ofse) then Halt(255);

delka_bloku:=Zjisti_delku_predavaneho_bloku(segm,ofse);
if delka_bloku<=0 then Halt(254);
GetMem(predavany_blok,delka_bloku);
Nacti_data_z_predavaneho_bloku(segm,ofse,delka_bloku,predavany_blok);


ped:=pointer(@predavany_blok[20]);
delka_ped:=@predavany_blok[16];
vyst_ofse:=@predavany_blok[12];
povel:=@predavany_blok[8];

bar.Init;
bar.FEncoding:=beEAN13;
s[0]:=char(delka_ped^);
move(ped^,s[1],delka_ped^);

if povel^=1 then VygenerujSeznamMoznychKodu(s,hotova_odpoved,delka_odpovedi) else
if (povel^>=100) and (povel^<200) then VygenerujBarKod(s,povel^,hotova_odpoved,delka_odpovedi);


{bar.Done;}

Zapis_data_do_bloku_pro_zapis(segm,vyst_ofse^,hotova_odpoved,delka_odpovedi);

FreeMem(predavany_blok);
FreeMem(hotova_odpoved)
end.
