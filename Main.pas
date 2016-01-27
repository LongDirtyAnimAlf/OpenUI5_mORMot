unit Main;

{$I Synopse.inc}

interface

uses
  {$ifdef MSWINDOWS}
  Windows,
  Messages,
  {$endif}
  {$ifdef Darwin}
  Unix,
  {$endif}
  SysUtils, Classes, Controls,
  Forms, StdCtrls, Dialogs,
  SynCommons, mORMot,
  mORMotSQLite3, SynSQLite3Static,
  SynCrtSock,
  dataserver,
  SampleData;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnOpen: TButton;
    btnRoot: TButton;
    Label1: TLabel;
    Button1: TButton;
    Label2: TLabel;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    procedure btnOpenClick(Sender: TObject);
    procedure btnRootClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    function OnLogEvent(Sender: TTextWriter; Level: TSynLogInfo;
      const Text: RawUTF8):boolean;
  public
    mORMotServer: TmORMotODataServer;
  end;



var
  Form1: TForm1;

implementation

{$ifdef FPC}
{$R *.lfm}
{$else}
{$R *.dfm}
{$endif}

uses
  {$ifdef FPC}
  LCLIntf; // for OpenURL
  {$else}
  ShellApi;
 {$endif}

{ TForm1 }

function TForm1.OnLogEvent(Sender: TTextWriter; Level: TSynLogInfo;
      const Text: RawUTF8):boolean;
begin
  result:=True;
  Memo1.Lines.Append(Text);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  Close;
end;

procedure TForm1.btnOpenClick(Sender: TObject);
begin
  {$ifdef MSWINDOWS}
  ShellExecute(0,'open','http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE,
      nil,nil,SW_SHOWNORMAL);
  {$else}
  {$ifdef FPC}
  OpenURL('http://'+HOST+':'+PORT+'/'+STATICROOT+'/'+INDEXFILE);
  {$endif}
  {$endif}
end;

procedure TForm1.btnRootClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    TCustomHttpServer(mORMotServer.Server).ServerRoot:=ExtractFileDir(OpenDialog1.FileName);
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  mORMotServer:=TmORMotODataServer.Create;
  OpenDialog1.InitialDir:=TCustomHttpServer(mORMotServer.Server).ServerRoot;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  mORMotServer.Free;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  Label1.Caption := Caption;
end;

end.
